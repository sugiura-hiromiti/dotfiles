// みため
glide.o.native_tabs = 'autohide';

type Palette = Record<
	| 'rosewater'
	| 'flamingo'
	| 'pink'
	| 'mauve'
	| 'red'
	| 'maroon'
	| 'peach'
	| 'yellow'
	| 'green'
	| 'teal'
	| 'sky'
	| 'sapphire'
	| 'blue'
	| 'lavender'
	| 'text'
	| 'subtext1'
	| 'subtext0'
	| 'overlay2'
	| 'overlay1'
	| 'overlay0'
	| 'surface2'
	| 'surface1'
	| 'surface0'
	| 'base'
	| 'mantle'
	| 'crust',
	`#${string}`
>;

const catppuccin: { dark: Palette; light: Palette; } = {
	dark: {
		rosewater: '#f2d5cf',
		flamingo: '#eebebe',
		pink: '#f4b8e4',
		mauve: '#ca9ee6',
		red: '#e78284',
		maroon: '#ea999c',
		peach: '#ef9f76',
		yellow: '#e5c890',
		green: '#a6d189',
		teal: '#81c8be',
		sky: '#99d1db',
		sapphire: '#85c1dc',
		blue: '#8caaee',
		lavender: '#babbf1',
		text: '#c6d0f5',
		subtext1: '#b5bfe2',
		subtext0: '#a5adce',
		overlay2: '#949cbb',
		overlay1: '#838ba7',
		overlay0: '#737994',
		surface2: '#626880',
		surface1: '#51576d',
		surface0: '#414559',
		base: '#303446',
		mantle: '#292c3c',
		crust: '#232634',
	},
	light: {
		rosewater: '#dc8a78',
		flamingo: '#dd7878',
		pink: '#ea76cb',
		mauve: '#8839ef',
		red: '#d20f39',
		maroon: '#e64553',
		peach: '#fe640b',
		yellow: '#df8e1d',
		green: '#40a02b',
		teal: '#179299',
		sky: '#04a5e5',
		sapphire: '#209fb5',
		blue: '#1e66f5',
		lavender: '#7287fd',
		text: '#4c4f69',
		subtext1: '#5c5f77',
		subtext0: '#6c6f85',
		overlay2: '#7c7f93',
		overlay1: '#8c8fa1',
		overlay0: '#9ca0b0',
		surface2: '#acb0be',
		surface1: '#bcc0cc',
		surface0: '#ccd0da',
		base: '#eff1f5',
		mantle: '#e6e9ef',
		crust: '#dce0e8',
	},
};

type Theme = 'dark' | 'light';

const theme: Theme = glide.prefs.get('dotfiles.glide.theme',) === 'light' ? 'light' : 'dark';
const palette = catppuccin[theme];

void browser.theme.update({
	colors: {
		frame: palette.base,
		toolbar: palette.base,
		toolbar_text: palette.text,
		toolbar_field: palette.surface0,
		toolbar_field_text: palette.text,
	},
},);

glide.o.hint_size = '12px';

glide.styles.add(
	`
  :root {
    /* Link hints */
    --glide-hint-background: ${palette.blue};
    --glide-hint-color: ${palette.surface0};
    --glide-hint-border: 1px solid ${palette.text};

    /* CommandLine */
    --glide-cmdl-bg: ${palette.base};
    --glide-cmdl-fg: ${palette.text};

    /* Completions */
    --glide-cmplt-bg: ${palette.base};
    --glide-cmplt-fg: ${palette.text};
    --glide-of-bg: ${palette.surface1};
    --glide-of-fg: ${palette.text};
    --glide-header-first-bg: ${palette.mantle};

    /* Modes */
    --glide-mode-normal: ${palette.blue};
    --glide-mode-insert: ${palette.green};
    --glide-mode-visual: ${palette.mauve};
    --glide-mode-hint: ${palette.peach};
    --glide-mode-command: ${palette.red};
  }

  /* Typed hint characters */
  div.glide-internal-hint-marker
    > .glide-matching-character {
    color: ${palette.peach};
  }

  div.glide-internal-hint-marker span {
    text-shadow: none;
  }
  `,
	{ id: 'catppuccin-glide', overwrite: true, },
);

glide.styles.add(
	`
  #nav-bar #back-button,
  #nav-bar #forward-button,
  #nav-bar #home-button,
  #nav-bar #stop-reload-button,
  #nav-bar #fxa-toolbar-menu-button {
    display: none !important;
  }
  `,
	{ id: 'minimal-toolbar', overwrite: true, },
);

// 操作感
glide.prefs.set("general.smoothScroll.lines", false);

// keybind
glide.g.mapleader = '<Space>';

glide.keymaps.set('normal', 'tt', 'commandline_show tab ',);
glide.keymaps.set('normal', 'tn', 'tab_new',);

glide.keymaps.set('normal', 'H', 'back',);
glide.keymaps.set('normal', 'L', 'forward',);

glide.keymaps.set('normal', 'gb', async () => {
	const tree = await browser.bookmarks.getTree();
	const bookmarks: { title: string; url: string; }[] = [];

	function collect(nodes: typeof tree,): void {
		for (const node of nodes) {
			if (node.url) {
				bookmarks.push({
					title: node.title,
					url: node.url,
				},);
			}
			if (node.children) {
				collect(node.children,);
			}
		}
	}

	collect(tree,);

	await glide.commandline.show({
		title: 'bookmarks',
		options: bookmarks.map(
			({ title, url, },) => ({
				label: title || url,
				description: url,
				async execute() {
					await browser.tabs.create({
						url,
						active: true,
					},);
				},
			}),
		),
	},);
}, { description: 'Search bookmarks', },);

glide.keymaps.set('normal', '<leader>w', async ({ tab_id }) => {
	const tab = await browser.tabs.get(tab_id);
	const windows = await browser.windows.getAll({
		populate: true, windowTypes: ['normal'],
	});

	const options: glide.CommandLineCustomOption[] = [
		{
			label: 'New window', description: 'Move tab to a new window', async execute() {
				await browser.windows.create({
					tabId: tab_id, focused: true,
				})
			}
		}
	];

	for (const win of windows) {
		if (win.id === undefined || win.id === tab.windowId || win.incognito !== tab.incognito) { continue; }

		const id = win.id;
		const active = win.tabs?.find((tab) => tab.active);
		options.push({
			label: active?.title || `Window ${id}`,
			description: `Window ${id}: ${win.tabs?.length ?? 0} tabs`,
			async execute() {
				await browser.tabs.move(tab_id, {
					windowId: id, index: -1,
				})
			}
		})
	}

	await glide.commandline.show({
		title: 'Move tab to window',
		options,
	});
}, { description: 'Move tab to another window' });
