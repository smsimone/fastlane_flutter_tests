describe Fastlane::Actions::FlutterTestsAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The flutter_tests plugin is working!")

      Fastlane::Actions::FlutterTestsAction.run(nil)
    end
  end
end
