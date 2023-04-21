require 'sorbet-runtime'

class Main
  extend T::Sig

  sig do
    params(kw: String).void
  end
  def self.main(kw = Time.now)
    puts "kw: #{kw}"
    puts "kw.is_a?(String): #{kw.is_a?(String)}"
  end
end

begin
  Main.main(123)
rescue StandardError => e
  puts "Error: #{e}"
end

loop do
  Main.main
  sleep 1
end