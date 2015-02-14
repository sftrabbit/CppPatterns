module CppSamples
	class CodeBlock < Jekyll::Tags::HighlightBlock
		def add_code_tag(code)
			code = code.sub(/<div.*><pre>\n*/,'').sub(/\n*<\/pre><\/div>/,'')
			code.strip!

			line_count = code.split("\n").length
			line_nums = ''
			(1..line_count).each do |line_num|
				line_nums += "#{line_num}\n"
			end

			output = '<table class="codeblock"><tr>'
			output += "<td class=\"linenums\"><pre><code>#{line_nums}</code></pre></td>"
			output += "<td class=\"code highlight\"><pre><code>#{code}</code></pre></td>"
			output += '</tr></table>'
		end
	end
end

Liquid::Template.register_tag('codeblock', CppSamples::CodeBlock)
