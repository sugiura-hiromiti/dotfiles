local fts = { 'markdown', 'noice', 'rust', 'typescript', 'javascript', 'scheme', 'Avante', 'cmp_docs' }

return {
	'MeanderingProgrammer/render-markdown.nvim',
	ft = fts,
	opts = {
		file_types = fts,
		code = { position = 'right', width = 'block', left_pad = 2, right_pad = 4 },
		heading = { width = 'block', min_width = 60 },
		indent = { enabled = true, per_level = 3 },
		latex = {
			enabled = true,
			converter = 'latex2text',
			highlight = 'RenderMarkdownMath',
			top_pad = 1,
			bottom_pad = 1,
		},
	},
}
