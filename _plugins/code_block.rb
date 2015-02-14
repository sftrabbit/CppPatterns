module CppSamples
	class CodeBlock < Jekyll::Tags::HighlightBlock
		def add_code_tag(code)
			code = code.sub(/<div.*><pre>\n*/,'').sub(/\n*<\/pre><\/div>/,'')
			code.strip!

			line_num = 0
			line_nums = ''
			code_lines = code.split("\n")
			code_lines.map! do |line|
				line_num += 1
				line_nums += "#{line_num}\n"
				leading_whitespace = /^\s*/.match(line)
				start_line = leading_whitespace[0].length
				"#{leading_whitespace}<span class=\"line#{line_num}\">#{line[start_line..-1]}</span>"
			end
			code = code_lines.join("\n")

			output = '<table class="codeblock"><tr>'
			output += "<td class=\"linenums\"><pre><code>#{line_nums}</code></pre></td>"
			output += "<td class=\"code highlight\"><pre><code>#{code}</code></pre></td>"
			output += '</tr></table>'
		end
	end
end

Liquid::Template.register_tag('codeblock', CppSamples::CodeBlock)
