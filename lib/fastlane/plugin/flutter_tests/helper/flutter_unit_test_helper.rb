require 'fastlane/action'
require_relative '../utils/utilities'

module Fastlane

  module Helper
    class FlutterUnitTestHelper
      def initialize
        @launched_tests = Hash.new { |hash, key| hash[key] = nil }
      end

      # Launches all the unit tests contained in the project
      # folder
      #
      # @param flutter_command [String] Contains the command to launch flutter
      # @param print_only_failed [Boolean] If true, prints only skipped and failed tests
      # @param print_stats [Boolean] If true, it prints a table containing the info about
      # the launched tests
      def run(flutter_command, print_only_failed, print_stats)
        Open3.popen3("#{flutter_command} test --machine") do |stdin, stdout, stderr, thread|
          stdout.each_line do |line|
            parse_json_output(line, print_only_failed)
          end
        end

        if print_stats
          stats = Hash.new { |hash, key| hash[key] = 0 }
          @launched_tests.values.each do |item|
            unless item.nil?
              stats[item.get_status] += 1
            end
          end

          skipped_tests = stats['skipped'].nil? ? 0 : stats['skipped']
          failed_tests = stats['error'].nil? ? 0 : stats['error']
          successful_tests = stats['success'].nil? ? 0 : stats['success']
          table = [
            %w[Successful Failed Skipped],
            [successful_tests, failed_tests, skipped_tests]
          ]

          messages = ["Ran #{@launched_tests.values.count { |e| !e.nil? }} tests"]
          colors = { 0 => 'green', 1 => 'red', 2 => 'blue' }
          max_length = 0
          (0..2).each do |i|
            msg = "#{table[0][i]}:\t#{table[1][i]}"
            max_length = [max_length, msg.length].max
            messages.append(Utilities.new.colorize(msg, colors[i]))
          end

          UI.message('-' * max_length)
          messages.each { |m| UI.message(m) }
          UI.message('-' * max_length)
        end
      end

      # Parses the json output given by [self.run]
      #
      # @param line [String] The json as string that has to be parsed
      # @param print_only_failed [Boolean] See definition on run
      def parse_json_output(line, print_only_failed)
        unless line.to_s.strip.empty?
          output = JSON.parse(line)
          unless output.kind_of?(Array)
            type = output['type']
            case type
            when 'testStart'
              id = output['test']['id']
              name = output['test']['name']
              if name.include?('loading')
                return
              end

              test_item = Test.new(id, name)
              @launched_tests[test_item.get_id] = test_item
            when 'testDone'
              test_id = output['testID']
              test_item = @launched_tests[test_id]
              if !test_item.nil? && test_item.can_print
                was_skipped = output['skipped']
                test_item.mark_as_done(output['result'], was_skipped, nil, nil)
                if was_skipped || !print_only_failed
                  UI.message(test_item.generate_message)
                end
              end
            when 'error'
              test_id = output['testID']
              test_item = @launched_tests[test_id]
              if !test_item.nil? && test_item.can_print
                test_item.mark_as_done('error', false, output['error'], output['stackTrace'])
                UI.message(test_item.generate_message)
              end
            else
              # ignored
            end
          end
        end
      rescue StandardError => e
        UI.error("Got error during parse_json: #{e.message}")
        UI.error(e.backtrace.join('\n'))
        exit(1)
      end
    end
  end
end
