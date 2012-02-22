require 'yaml'

$config = YAML::load_file(File.join(File.dirname(__FILE__), "../config.yaml"))
$config.each_pair { |key, value|
  puts "#{key} = #{value}"
}