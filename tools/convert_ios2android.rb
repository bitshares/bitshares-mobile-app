require 'pp'
require 'fileutils'
require 'builder'

module AndroidI18nGeneration

  CFG = {
    files_mapping: {
      "en.lproj/Localizable.strings"      => "values/strings.xml",      # => en
      "zh-Hans.lproj/Localizable.strings" => "values-zh/strings.xml",   # => zh
      "ja.lproj/Localizable.strings"      => "values-ja/strings.xml",   # => ja
    },
    ios_base_dir: File.expand_path(File.join("..", 'ios/oplayer/Resources')),
    android_base_dir: File.expand_path(File.join("..", 'android/app/src/main/res')),
  }

  def self.load_file(src_filename, base_filename)
    content = open(src_filename, "rb"){|fr| fr.read} rescue nil
    if content.nil?
      puts "ERROR> load file error: #{base_filename}" 
      return nil
    end
    list = []
    group = nil
    content.each_line do |line|
      if line =~ /\/\*\s*?(\S+)\s*?\*\//
        list << group if group
        group = {:name=>$1, :values=>[]}
      elsif line =~ /.*?"(.+?)".*?=.*?"(.+?)";/
        group ||= {:name=>'Default', :values=>[]}
        k = $1
        v = $2
        # => process special characters
        v.gsub!(/@/, 's')
        group[:values] << {k:k, v:v}
      end
    end
    list << group if group
    return list
  end

  def self.write_file(dst_filename, base_filename, list)
    FileUtils.mkdir_p(File.dirname(dst_filename))
    open(dst_filename, "wb") do |fw|
      builder = Builder::XmlMarkup.new(:target=>fw, :indent=>4)
      builder.comment! "The xml file is automatically generated, please do not modify it!!! by syalon."
      builder.resources do |b| 
        list.each do |group|
          b.comment! group[:name]
          group[:values].each{|item| b.string(item[:v], :name=>item[:k])}
        end
      end
    end
    puts "INFO> write `#{base_filename}' done."
  end

  def self.run
    CFG[:files_mapping].each do |k, v|
      src = "#{CFG[:ios_base_dir]}/#{k}"
      dst = "#{CFG[:android_base_dir]}/#{v}"
      list = load_file(src, k)
      next if list.nil?
      write_file(dst, v, list)
    end
    puts "===== all done ====="
  end
end

AndroidI18nGeneration.run


