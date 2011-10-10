require 'fileutils'

# Precompiles handlebars templates into JavaScript function strings
class Handlebars

  @@header = '!function() { var template = Handlebars.template, templates = Handlebars.templates = Handlebars.templates || {};'
  @@footer = '}()'

  class << self

    # Recursively compiles a source directory of .handlebars templates into a 
    # destination directory. Immitates the node.js bin script at
    # https://github.com/wycats/handlebars.js/blob/master/bin/handlebars
    #
    # Arguments:
    #   root_path (string) - The root directory to find templates to compile
    #   compiled_path (string) - The destination directory in which to save the
    #     compiled templates.
    def compile(root_path, compiled_path)
      files = Dir["#{root_path}/**/**.handlebars"]
      files.each { |file| compile_file file, root_path, compiled_path }
    end

    # Compiles a single file into a destination directory.
    #
    # Arguments:
    #   file (string) - The file to compile.
    #   root_path - See `compile`
    #   compiled_path - See `compile`
    def compile_file(file, root_path, compiled_path)
      id       = file.gsub(root_path+'/', '').gsub(/.handlebars$/, '')
      path     = "#{compiled_path}/#{id}.js"
      dir      = File.dirname(path)
      source   = File.read(file)
      js       = compile_template(source, id)
      FileUtils.mkdir_p(dir) unless File.exists?(dir)
      File.open(path, 'w') { |file| file.write(js) }
    end

    def compile_template(source, id)
      require 'execjs'
      # if the first letter of the template name is "_", register it as a partial
      # ex: _foobar.handlebars or subfolder/_something.handlebars
      filename = File.basename(id)
      if filename.match(/^_/)
        partial_name = filename.sub(/^_/, "")
        partial_path = id.sub(filename, partial_name)
        partial_registration = "\nHandlebars.registerPartial('#{partial_path}', templates['#{id}']);\n"
      end
      template = context.call "Handlebars.precompile", prepare_i18n(source, id)
      "#{@@header}\ntemplates['#{id}'] = template(#{template}); #{partial_registration}#{@@footer}"
    end

    def prepare_i18n(source, scope)
      scope = scope.sub('/', '.')
      source.gsub(/\{\{#t "(.*?)"([^\}]*)\}\}(.*?)\{\{\/t\}\}/m){
        key = $1
        options = $2
        content = $3
        content.strip!
        content.gsub!(/\s+/, ' ')
        content.gsub!(/\{\{(.*?)\}\}/){
          var = $1
          raise "helpers may not be used inside translate calls" unless var =~ /\A[a-z0-9_\.]+\z/
          "%{#{var}}"
        }
        wrappers = {}
        content.gsub!(/((<([a-zA-Z])[^>]*>)+)([^<]+)((<\/\3>)+(<\/[^>]+>)*)/){
          value = "#{$1}$1#{$5}"
          delimiter = wrappers[value] ||= '*' * (wrappers.size + 1)
          "#{delimiter}#{$4}#{delimiter}"
        }
        wrappers = wrappers.map{ |value, delimiter| "w#{delimiter.size-1}=#{value.inspect}" }.join(' ')
        wrappers = ' ' + wrappers unless wrappers.empty?
        "{{{t #{key.inspect} #{content.inspect} scope=#{scope.inspect}#{wrappers}#{options}}}}"
      }
    end

    protected

    # Returns the JavaScript context
    def context
      @context ||= self.set_context
    end

    # Compiles and caches the handlebars JavaScript
    def set_context
      handlebars_source = File.read(File.dirname(__FILE__) + '/vendor/handlebars.js')
      @context = ExecJS.compile handlebars_source
    end
  end
end