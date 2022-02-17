require 'fastlane/action'
require 'open3'
require_relative '../utils/utilities.rb'

module Fastlane
  module Helper
    class FlutterIntegrationTestHelper
      # Initialize the helper that launches the integration tests
      #
      # @param driver [String] the path to the file that will be used as driver
      # @param test_folder [String] the path to the folder that contains the
      # @param flutter_command [String] the command to launch flutter
      # integration tests
      def initialize(driver, test_folder, flutter_command)
        @driver = driver
        @integration_tests = _load_files(test_folder)
        @flutter_command = flutter_command
      end

      # Loads all the integration test files
      #
      # @param test_folder [String] the path that contains the test files
      # @return [Array] An array containing all the paths to the files found
      def _load_files(test_folder)
        test_files = Dir.glob("#{test_folder}/**/*").reject do |f|
          File.directory?(f) || !f.end_with?('_test.dart')
        end
        UI.message("Found #{test_files.length} test files")
        test_files
      end

      # Launches the tests sequentially
      #
      # @param platform [String] Specifies on which platform the tests should be run
      # @param force_launch [Boolean] If it's true and there aren't any devices ready, the plugin will try to start one for the given platform
      # @param reuse_build [Boolean] If it's true, it will run the build only for the first integration test
      # @return [Integer] Value 0 or 1 if all tests were run correctly or not
      def run(platform, force_launch, reuse_build)
        UI.message("Checking for running devices")
        device_id = _run_test_device(platform, force_launch)
        if !device_id.nil?
          _launch_tests(device_id, reuse_build)
        else
          UI.error("Failed to find a device to launch the tests on")
          exit(1)
        end
      end

      # Executes the tests found on the device_id
      #
      # @param device_id [String] the id of the device previously found
      # @param reuse_build [Boolean] If it's true, it will run the build only for the first integration test
      # @return [Integer] Value 0 or 1 if all tests were run correctly or not
      def _launch_tests(device_id, reuse_build)
        apk_path = nil
        if reuse_build
          UI.message("Building apk")
          out, err, status = Open3.capture3("#{@flutter_command} build apk")
          if _get_exit_code(status) != '0'
            UI.error("Failed to build apk")
            puts err
            exit(1)
          else
            apk_path = _get_apk_path(out)
            if !apk_path.nil? && File.file?(apk_path)
              UI.message("Build apk at path #{apk_path}")
              #TODO
            else
              UI.error("Apk path not found or it's not accessible")
              exit(1)
            end

          end
        end

        count = 0

        tests = {
          "successful" => 0,
          "failed" => 0,
        }

        @integration_tests.each do |test|
          UI.message("Launching test #{count}/#{@integration_tests.length}: #{test.split("/").last}")
          _, __, status = Open3.capture3("#{@flutter_command} drive --target #{@driver} --driver #{test} -d #{device_id} #{reuse_build ? "--use-application-binary #{apk_path}" : ''}")
          successful = _get_exit_code(status) == '0'
          color = successful ? 'green' : 'red'
          tests[successful ? 'successful' : 'failed'] += 1

          UI.message(Utilities.new.colorize("Test #{test.split("/").last} #{successful ? 'terminated correctly' : 'failed'}", color))
          count += 1
        end

        if tests['failed'] != 0
          UI.error("Some integration tests failed")
          1
        else
          0
        end

      end

      # Returns the exit code of a process
      #
      # @param exit_status [String] status given back by [Open3]
      # @return The exit code (0|1) as string
      def _get_exit_code(exit_status)
        exit_status.to_s.split(' ').last
      end

      # Parse the flutter build output looking for a .apk path
      #
      # @param message [String] the stdout of flutter build process
      # @return the path to the apk that has been built
      def _get_apk_path(message)
        components = message.split(/\n/).last.split(' ')
        if components.any? { |line| line.end_with? '.apk' }
          components.detect { |c| c.end_with? '.apk' }
        else
          UI.warn('Apk path not found in the stdout')
          nil
        end
      end

      # Checks if there's a device running and gets its id
      # @param platform [String] Specifies the type of device that should be found
      # @param force_launch [Boolean] If it's true and there aren't any devices ready, the plugin will try to start one for the given platform
      # @return The deviceId if the device exists or [nil]
      def _run_test_device(platform, force_launch)
        out, _ = Open3.capture2("#{@flutter_command} devices | grep #{platform}")
        device_id = nil
        if out.to_s.strip.empty? && force_launch
          out, _ = Open3.capture2("#{@flutter_command} emulators | grep #{platform}")
          if out.to_s.strip.empty?
            UI.error("No emulators found for platform #{platform}")
            exit(1)
          end

          emulator_id = out.to_s.split('•')[0]
          Open3.capture2("#{@flutter_command} emulators --launch #{emulator_id}")

          out, _ = Open3.capture2("#{@flutter_command} devices | grep #{platform}")
        else
          device_id = (out.to_s.split("•")[1]).strip
          UI.message("Found already running device: #{device_id}")
        end

        unless out.to_s.strip.empty?
          device_id = (out.to_s.split("•")[1]).strip
          UI.message("Got device id #{device_id}")
        end

        device_id.nil? ? nil : device_id
      end
    end
  end
end
