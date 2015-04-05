require_relative "./diff_parser"
module RuboCop::Canvas
  class Comments
    def self.build(raw_diff_tree, cop_output)
      diff = DiffParser.new(raw_diff_tree)
      comments = self.new(diff)
      comments.on_output(cop_output)
    end

    attr_reader :diff
    def initialize(diff)
      @diff = diff
    end

    def on_output(cop_output)
      comments = []
      cop_output['files'].each do |file|
        path = file['path']
        file['offenses'].each do |offense|
          if diff.relevant?(path, line_number(offense))
            comments << transform_to_gergich_comment(path, offense)
          end
        end
      end
      comments
    end

    private

    SEVERITY_MAPPING = {
      'refactor' => 'info',
      'convention' => 'info',
      'warning' => 'warn',
      'error' => 'error',
      'fatal' => 'error'
    }.freeze

    def transform_to_gergich_comment(path, offense)
      {
        path: path,
        position: line_number(offense),
        message: offense['message'],
        severity: SEVERITY_MAPPING[offense['severity']]
      }
    end

    def line_number(offense)
      offense['location']['line']
    end

  end

end
