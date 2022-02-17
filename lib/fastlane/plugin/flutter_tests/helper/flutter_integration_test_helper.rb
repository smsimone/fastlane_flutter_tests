require 'fastlane/action'
require 'open3'

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
        test_files = Dir.glob("#{test_folder}/**/*").reject { |f|
          File.directory?(f) || !f.end_with?('_test.dart')
        }
        UI.message("Found #{test_files.length} test files")
        test_files
      end

      # Launches the tests sequentially
      #
      # @param platform [String] Specifies on which platform the tests should be run
      # @param force_launch [Boolean] If it's true and there aren't any devices ready, the plugin will try to start one for the given platform
      def run(platform, force_launch)
        UI.message("Checking for running devices")
        device_id = _run_test_device(platform, force_launch)
        if !device_id.nil?
          _launch_tests(device_id)
        else
          UI.error("Failed to find a device to launch the tests on")
          exit(1)
        end
      end

      # Executes the tests found on the device_id
      #
      # @param device_id [String] the id of the device previously found
      def _launch_tests(device_id)
        @integration_tests.each { |test|
          UI.message("Launching test #{test}")
          _, __, status = Open3.capture3("#{@flutter_command} drive --target #{@driver} --driver #{test} -d #{device_id}")
          UI.message("Test #{test} ended with code #{status}")
        }
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
