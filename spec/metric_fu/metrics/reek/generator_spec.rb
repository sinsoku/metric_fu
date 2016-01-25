require "spec_helper"
MetricFu.metrics_require { "reek/generator" }

describe MetricFu::ReekGenerator do
  describe "emit" do
    let(:options) { { dirs_to_reek: [] } }
    let(:files_to_analyze) { ["lib/foo.rb", "lib/bar.rb"] }
    let(:reek) { MetricFu::ReekGenerator.new(options) }

    before :each do
      allow(reek).to receive(:files_to_analyze).and_return(files_to_analyze)
    end

    it "includes config file pattern into reek parameters when specified" do
      options.merge!(config_file_pattern: "lib/config/*.reek")

      expect(reek).to receive(:run!) do |_files, config_files|
        expect(config_files).to eq(["lib/config/*.reek"])
      end.and_return("")

      reek.emit
    end

    it "passes an empty array when no config file pattern is specified" do
      expect(reek).to receive(:run!) do |_files, config_files|
        expect(config_files).to eq([])
      end.and_return("")

      reek.emit
    end

    it "includes files to analyze into reek parameters" do
      expect(reek).to receive(:run!) do |files, _config_files|
        expect(files).to eq(["lib/foo.rb", "lib/bar.rb"])
      end.and_return("")

      reek.emit
    end
  end

  describe "analyze method" do
    before :each do
      MetricFu::Configuration.run {}
      allow(File).to receive(:directory?).and_return(true)
      @reek = MetricFu::ReekGenerator.new
      @examiner = @reek.send(:examiner)
      @smell_warning = Reek.const_defined?(:SmellWarning) ? Reek.const_get(:SmellWarning) : Reek.const_get(:Smells).const_get(:SmellWarning)
      if @smell_warning.instance_methods.include?(:subclass)
        @smell_warning.send(:alias_method, :smell_type, :subclass)
      end
    end

    context "with reek warnings" do
      before :each do
        @smells = {
          'app/controllers/activity_reports_controller.rb' => [
            instance_double(@smell_warning,
                            context: "ActivityReportsController#authorize_user",
                            message: "calls current_user.primary_site_ids multiple times",
                            smell_type: "Duplication",
                            lines: [2, 4]),
            instance_double(@smell_warning,
                            context: "ActivityReportsController#authorize_user",
                            message: "calls params[id] multiple times",
                            smell_type: "Duplication",
                            lines: [5, 7]),
            instance_double(@smell_warning,
                            context: "ActivityReportsController#authorize_user",
                            message: "calls params[primary_site_id] multiple times",
                            smell_type: "Duplication",
                            lines: [11, 15]),
            instance_double(@smell_warning,
                            context: "ActivityReportsController#authorize_user",
                            message: "has approx 6 statements",
                            smell_type: "Long Method",
                            lines: [8])
          ], 'app/controllers/application.rb' => [
            instance_double(@smell_warning,
                            context: "ApplicationController#start_background_task/block/block",
                            message: "is nested",
                            smell_type: "Nested Iterators",
                            lines: [23])
          ], 'app/controllers/link_targets_controller.rb' => [
            instance_double(@smell_warning,
                            context: "LinkTargetsController#authorize_user",
                            message: "calls current_user.role multiple times",
                            smell_type: "Duplication",
                            lines: [8])
          ], 'app/controllers/newline_controller.rb' => [
            instance_double(@smell_warning,
                            context: "NewlineController#some_method",
                            message: "calls current_user.<< \"new line\n\" multiple times",
                            smell_type: "Duplication",
                            lines: [6, 9])
          ]
        }
        @output = @smells.map do |description, smells|
          instance_double(@examiner, description: description, smells: smells)
        end
        @reek.instance_variable_set(:@output, @output)
        @matches = @reek.analyze
      end

      it "should find the code smell's line numbers" do
        smell = @matches.first[:code_smells].first
        expect(smell[:lines]).to eq([2, 4])
      end

      it "should find the code smell's method name" do
        smell = @matches.first[:code_smells].first
        expect(smell[:method]).to eq("ActivityReportsController#authorize_user")
      end

      it "should find the code smell's type" do
        smell = @matches[1][:code_smells].first
        expect(smell[:type]).to eq("Nested Iterators")
      end

      it "should find the code smell's message" do
        smell = @matches[1][:code_smells].first
        expect(smell[:message]).to eq("is nested")
      end

      it "should find the code smell's type" do
        smell = @matches.first
        expect(smell[:file_path]).to eq("app/controllers/activity_reports_controller.rb")
      end

      it "should NOT insert nil smells into the array when there's a newline in the method call" do
        expect(@matches.last[:code_smells]).to eq(@matches.last[:code_smells].compact)
      end
    end
  end
end
