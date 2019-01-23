#!/usr/bin/env ruby

require 'pp'
require 'digest'
require 'base64'

def exit_with_err(errmsg = nil)
  if errmsg
    print errmsg
    print "\n"
    exit(1)   # => 告诉xcode脚本出错了
  else
    exit(0)
  end 
end

# => TODO:fowallet 暂时不用预处理
print "CTM macro processor, skip...\n"
exit_with_err(nil)

# => 缺少参数报错
exit_with_err("CTM macro processor miss arguments") if ARGV.empty?

def scan_dir(rootdir, relativedir, blk)
  fulldirname = rootdir + relativedir
  Dir.foreach(fulldirname) do |s|
    next if s == '.' || s == '..'
    if FileTest.directory?(fulldirname + s)
      scan_dir(rootdir, relativedir + s + '/', blk)
    else
      blk.call(relativedir, s)
    end
  end
end

def scan_files(root_dir, &blk)
  scan_dir(root_dir, '', blk)
end

def scan_all_source(project_root_dir)
  files = []
  scan_files(project_root_dir) do |relativedir, s|
    next unless s =~ /\.(m|mm|c|h)$/i
    next if s =~ /^\._/i
    # => 略过自身
    next if s =~ /CompileTimeMacro/
    files << relativedir + s
  end
  return files
end

def scan_all_backfile(project_root_dir)
  files = []
  scan_files(project_root_dir) do |relativedir, s|
    next unless s =~ /\.ctmbak$/i
    next if s =~ /^\._/i
    files << relativedir + s
  end
  return files
end

def md5(value)
  return Digest::MD5.hexdigest(value.to_s).upcase
end

# => '=' + 异或 & base64
def xorbase64(value)
  return '=' + Base64.strict_encode64(value.to_s.unpack("C*").map{|v| v ^= 0x12}.pack("C*"))
end

def process_compile_function(raw, funcname, args)
  case funcname
  when "MD5"
    args02 = args.strip
    if args02 =~ /^@"(.*)"$/
      return '@"' + md5($1) + '"' + "/*CTM_#{funcname}(#{args02})*/"
    end
    # => 无效参数直接返回
    return raw
  when "XORB64"
    args02 = args.strip
    if args02 =~ /^@"(.*)"$/
      return '@"' + xorbase64($1) + '"' + "/*CTM_#{funcname}(#{args02})*/"
    end
    # => 无效参数直接返回
    return raw
  else
    # => 不支持的函数直接返回
    return raw
  end
end

def process_file(filename, root_dir)
  content = open(root_dir + filename, "rb"){|fr| fr.read}
  # => 判断是否含有预处理宏
  if content =~ /__CTM_/
    # => 备份
    open(root_dir + filename + ".ctmbak", "wb"){|fw| fw.write content}
    # 解析所有 __CTM_(参数) 格式的预处理宏
    new_content = content.gsub(/__CTM_(.*?)\((.*?)\)/){|m| process_compile_function(m, $1, $2)}
    open(root_dir + filename, "wb"){|fw| fw.write new_content}
    print "CTM process #{filename}~ done~\n"
  else
    # puts "process #{filename}~ skip~"
  end
end

# => 模式：Release模式下处理预处理宏
def process_mode_release
  # => 获取所有源文件
  project_root_dir = File.expand_path("../oplayer", __FILE__) + "/"
  source_files = scan_all_source project_root_dir

  # => 处理编译时宏
  source_files.each{|f| process_file(f, project_root_dir)}

  # => 完毕
  print "CTM macro processor done~\n"

  # => 正常退出
  exit_with_err
end

# => 模式：还原先前处理的内容
def process_mode_restore
  project_root_dir = File.expand_path("../oplayer", __FILE__) + "/"
  backup_files = scan_all_backfile project_root_dir
  backup_files.each do |backupfile|
    backupfile =~ /(.*)\.ctmbak$/i
    origin_filename = $1
    compiled_content = open(project_root_dir + origin_filename, "rb"){|fr| fr.read}
    backup_content = open(project_root_dir + backupfile, "rb"){|fr| fr.read}
    open(project_root_dir + origin_filename + ".compiled", "wb"){|fw| fw.write compiled_content}
    open(project_root_dir + origin_filename, "wb"){|fw| fw.write backup_content}
    File.delete(project_root_dir + backupfile) rescue nil
    print "CTM restore: #{origin_filename}\n"
  end
end

# => 入口
mode = ARGV.first
if mode == 'Release'
  process_mode_release
elsif mode == 'Restore'
  process_mode_restore
else
  print "CTM macro processor, omit debug mode...\n"
  exit_with_err
end
