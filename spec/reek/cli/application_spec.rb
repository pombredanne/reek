require_relative '../../spec_helper'
require_lib 'reek/cli/application'

RSpec.describe Reek::CLI::Application do
  describe '#initialize' do
    it 'exits with default error code on invalid options' do
      call = lambda do
        Reek::CLI::Silencer.silently do
          Reek::CLI::Application.new ['--foo']
        end
      end
      expect(call).to raise_error(SystemExit) do |error|
        expect(error.status).to eq Reek::CLI::Options::DEFAULT_ERROR_EXIT_CODE
      end
    end
  end

  let(:path_excluded_in_configuration) do
    SAMPLES_PATH.join('source_with_exclude_paths/ignore_me/uncommunicative_method_name.rb')
  end

  let(:configuration) { test_configuration_for(SAMPLES_PATH.join('configuration/with_excluded_paths.reek')) }

  describe '#execute' do
    let(:command) { double 'reek_command' }
    let(:app) { Reek::CLI::Application.new [] }

    before do
      allow(Reek::CLI::Command::ReportCommand).to receive(:new).and_return command
      allow(command).to receive(:execute).and_return 'foo'
    end

    it "returns the command's result code" do
      expect(app.execute).to eq 'foo'
    end

    context 'when no source files given' do
      context 'and input was piped' do
        before do
          allow_any_instance_of(IO).to receive(:tty?).and_return(false)
        end

        it 'should use source form pipe' do
          app.execute
          expect(Reek::CLI::Command::ReportCommand).to have_received(:new).
            with(sources: [$stdin],
                 configuration: Reek::Configuration::AppConfiguration,
                 options: Reek::CLI::Options)
        end
      end

      context 'and input was not piped' do
        before do
          allow_any_instance_of(IO).to receive(:tty?).and_return(true)
        end

        it 'should use working directory as source' do
          expected_sources = Reek::Source::SourceLocator.new(['.']).sources
          app.execute
          expect(Reek::CLI::Command::ReportCommand).to have_received(:new).
            with(sources: expected_sources,
                 configuration: Reek::Configuration::AppConfiguration,
                 options: Reek::CLI::Options)
        end
      end

      context 'when source files are excluded through configuration' do
        let(:app) { Reek::CLI::Application.new ['--config', 'some_file.reek'] }

        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with('some_file.reek').and_return true
          allow(Reek::Configuration::AppConfiguration).
            to receive(:from_path).
            with(Pathname.new('some_file.reek')).
            and_return configuration
        end

        it 'should use configuration for excluded paths' do
          expected_sources = Reek::Source::SourceLocator.
            new(['.'], configuration: configuration).sources
          expect(expected_sources).not_to include(path_excluded_in_configuration)

          app.execute

          expect(Reek::CLI::Command::ReportCommand).to have_received(:new).
            with(sources: expected_sources,
                 configuration: configuration,
                 options: Reek::CLI::Options)
        end
      end
    end

    context 'when source files given' do
      let(:app) { Reek::CLI::Application.new ['.'] }

      it 'should use sources from argv' do
        expected_sources = Reek::Source::SourceLocator.new(['.']).sources
        app.execute
        expect(Reek::CLI::Command::ReportCommand).to have_received(:new).
          with(sources: expected_sources,
               configuration: Reek::Configuration::AppConfiguration,
               options: Reek::CLI::Options)
      end
    end
  end
end
