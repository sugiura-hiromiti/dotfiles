// みため
// glide.o.native_tabs = 'autohide';

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
		// Tabs
		frame: palette.mantle,
		frame_inactive: palette.crust,
		tab_selected: palette.base,
		tab_text: palette.mauve,
		tab_background_text: palette.blue,
		tab_loading: palette.yellow,

		// Toolbar
		toolbar: palette.mantle,
		toolbar_text: palette.mauve,
		icons: palette.blue,
		icons_attention: palette.peach,

		// Address bar
		toolbar_field: palette.base,
		toolbar_field_text: palette.mauve,
		toolbar_field_focus: palette.base,
		toolbar_field_text_focus: palette.mauve,
		toolbar_field_highlight: palette.surface0,
		toolbar_field_highlight_text: palette.text,

		// Interaction
		button_background_hover: palette.surface0,
		button_background_active: palette.surface1,

		// Popups
		popup: palette.base,
		popup_text: palette.text,
		popup_highlight: palette.surface0,
		popup_highlight_text: palette.mauve,
	},
});

glide.o.hint_size = '13px';

glide.styles.add(
	`
  :root {
    /* Link hints */
    --glide-hint-background: ${palette.blue};
    --glide-hint-color: ${palette.surface0};
    --glide-hint-border: 1px solid ${palette.text};

    /* CommandLine */
    --glide-cmdl-bg: ${palette.base};
    --glide-cmdl-fg: ${palette.mauve};

    /* Completions */
    --glide-cmplt-bg: ${palette.base};
    --glide-cmplt-fg: ${palette.text};

    /* Focused option */
    --glide-of-bg: ${palette.surface0};
    --glide-of-fg: ${palette.blue};

    /* Section header */
    --glide-header-first-bg: ${palette.base};

/* Flat design */
--glide-cmplt-border-top: none;
--glide-header-border-bottom: none;

/* Modes */
--glide-mode-normal: ${palette.blue};
--glide-mode-insert: ${palette.green};
--glide-mode-visual: ${palette.mauve};
--glide-mode-hint: ${palette.peach};
--glide-mode-command: ${palette.red};
  }

  /* Remove shadows and separators */
  .glide-commandline-container {
	box-shadow: none!important;
}

[anonid = "glide-commandline-holder"] {
	border-top: none!important;
}

/* Hover */
[anonid = "glide-commandline-completions"]
	.gcl-option:not(.focused):hover {
	background: ${palette.surface0} !important;
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
/* CommandLine */
[anonid="glide-commandline-completions"] .section-header {
  color: ${palette.sapphire};
}

.ExcmdCompletionOption:not(.focused) td.excmd {
  color: ${palette.pink};
}

.ExcmdCompletionOption:not(.focused) td.documentation {
  color: ${palette.lavender};
}

.ExcmdCompletionOption:not(.focused) td.keymap {
  color: ${palette.yellow};
}

.TabCompletionOption:not(.focused) td.label {
  color: ${palette.green};
}

.TabCompletionOption:not(.focused) td.url {
  color: ${palette.teal} !important;
}

.TabCompletionOption:not(.focused) td.status {
  color: ${palette.peach};
}

.CustomCompletionOption:not(.focused) td.label {
  color: ${palette.rosewater};
}

.CustomCompletionOption:not(.focused) td.description {
  color: ${palette.sky};
}

/* Which-key */
#which-key {
  background: ${palette.base} !important;
  border: none !important;
  box-shadow: none !important;
}

#which-key > div:first-child {
  background: ${palette.base} !important;
  border-bottom: none !important;
}

#which-key > div:first-child span {
  color: ${palette.sapphire} !important;
}

#which-key tbody td:first-child {
  background: transparent !important;
  color: ${palette.mauve} !important;
}

#which-key tbody tr:nth-child(6n + 2) td:first-child {
  color: ${palette.blue} !important;
}

#which-key tbody tr:nth-child(6n + 3) td:first-child {
  color: ${palette.green} !important;
}

#which-key tbody tr:nth-child(6n + 4) td:first-child {
  color: ${palette.peach} !important;
}

#which-key tbody tr:nth-child(6n + 5) td:first-child {
  color: ${palette.pink} !important;
}

#which-key tbody tr:nth-child(6n + 6) td:first-child {
  color: ${palette.yellow} !important;
}

#which-key tbody td:last-child {
  color: ${palette.text} !important;
}
  /* Hint colors */
  :root {
	--glide-hint-background: ${palette.green};
	--glide-hint-color: ${palette.base};
	--glide-hint-border: none;
	--glide-search-highlight-color: ${palette.yellow};
}

  /* Findbar */
  findbar {
	background: ${palette.base} !important;
	color: ${palette.text} !important;
	border: none!important;
	box-shadow: none!important;
}

findbar .findbar-textbox {
	background: ${palette.surface0} !important;
	color: ${palette.text} !important;
	border: none!important;
	box-shadow: none!important;
}

findbar .findbar-textbox[status = "notfound"] {
	background: ${palette.red} !important;
	color: ${palette.base} !important;
}
`,
	{ id: 'colorful-browser-ui', overwrite: true },
);

glide.styles.add(
	`
#nav-bar #back-button,
	#nav-bar #forward-button,
		#nav-bar #home-button,
			#nav-bar #stop-reload-button,
				#nav-bar #fxa-toolbar-menu-button {
	display: none!important;
}
`,
	{ id: 'minimal-toolbar', overwrite: true, },
);

glide.styles.add(
	`
  #glide-toolbar-mode-button {
    background: var(--glide-current-mode-color) !important;
    color: ${palette.base} !important;
    border: none !important;
    box-shadow: none !important;
  }

  #glide-toolbar-mode-button::after {
    display: none !important;
  }
  `,
	{ id: 'mode-indicator', overwrite: true },
);

glide.styles.add(
	`
  /* Glide notifications only */
  notification-message[value^="glide-"] {
    --info-bar-background-color: ${palette.base};
    --info-bar-text-color: ${palette.text};
    --info-bar-box-shadow: none;
    --message-bar-border-width: 0px;
    --message-bar-icon-background-color: transparent;
  }

  /* Information */
  notification-message[value^="glide-"][type="info"] {
    --info-bar-text-color: ${palette.mauve};
    --message-bar-icon-color: ${palette.blue};
    --icon-color-information: ${palette.blue};
  }

  /* Warning */
  notification-message[value^="glide-"][type="warning"] {
    --info-bar-text-color: ${palette.text};
    --message-bar-icon-color: ${palette.yellow};
    --icon-color-warning: ${palette.yellow};
  }

  /* Error */
  notification-message[value^="glide-"][type="critical"] {
    --info-bar-text-color: ${palette.red};
    --message-bar-icon-color: ${palette.red};
    --icon-color-critical: ${palette.red};
  }

  /* Action buttons */
  notification-message[value^="glide-"] .notification-button {
    background: ${palette.surface0} !important;
    color: ${palette.teal} !important;
    border: none !important;
    box-shadow: none !important;
  }

  notification-message[value^="glide-"] .notification-button:hover {
    background: ${palette.surface1} !important;
    color: ${palette.green} !important;
  }
  `,
	{ id: 'glide-notifications', overwrite: true },
);

glide.styles.add(
	`
  #urlbar {
    --urlbarview-background-color-selected: ${palette.surface0};
    --urlbarview-background-color-hover: ${palette.surface0};
    --urlbarview-text-color-selected: ${palette.text};
    --urlbarview-text-color-hover: ${palette.text};
  }

  /* Popup background */
  #urlbar .urlbarView-background {
    background-color: ${palette.base} !important;
    border: none !important;
    box-shadow: none !important;
  }

  #urlbar .urlbarView-results {
    border-top: none !important;
  }

  /* Default titles */
  #urlbar .urlbarView-row .urlbarView-title {
    color: ${palette.pink} !important;
  }

  /* Search suggestions */
  #urlbar .urlbarView-row:is(
    [type="search"],
    [type="rich-search"]
  ) .urlbarView-title {
    color: ${palette.blue} !important;
  }

  /* Bookmarks */
  #urlbar .urlbarView-row[type="bookmark"]
    .urlbarView-title {
    color: ${palette.green} !important;
  }

  /* History */
  #urlbar .urlbarView-row:is(
    [type="history"],
    [type="adaptive-history"],
    [type="semantic-history"]
  ) .urlbarView-title {
    color: ${palette.lavender} !important;
  }

  /* Open tabs */
  #urlbar .urlbarView-row:is(
    [type="switchtab"],
    [type="remotetab"]
  ) .urlbarView-title {
    color: ${palette.peach} !important;
  }

  /* URLs */
  #urlbar .urlbarView-url {
    color: ${palette.teal} !important;
  }

  /* Actions */
  #urlbar .urlbarView-action {
    color: ${palette.yellow} !important;
  }

  /* Tags */
  #urlbar .urlbarView-tag {
    color: ${palette.mauve} !important;
    background: transparent !important;
    border: none !important;
  }

  /* Selected title */
  #urlbar .urlbarView-row[selected]
    .urlbarView-title {
    color: ${palette.blue} !important;
  }
  `,
	{ id: 'colorful-urlbar', overwrite: true },
);

// 操作感
glide.prefs.set('general.smoothScroll.lines', false,);
glide.autocmds.create("UrlEnter", /.*/, async () => {
	await glide.excmds.execute("mode_change normal");
});

// keybind
// glide.g.mapleader = '';

glide.keymaps.del('normal', '.');

glide.keymaps.set('normal', 'H', 'back',);
glide.keymaps.set('normal', 'L', 'forward',);
glide.keymaps.set('normal', 'q', 'tab_prev', { description: 'tab prev' });
glide.keymaps.set('normal', 'w', 'tab_next', { description: 'tab next' });

// 表示操作
glide.keymaps.set('normal', '.t', 'tab_new', { description: 'tab new' });
glide.keymaps.set('normal', '.w', async ({ tab_id, },) => {
	const tab = await browser.tabs.get(tab_id,);
	const windows = await browser.windows.getAll({
		populate: true,
		windowTypes: ['normal',],
	},);

	const options: glide.CommandLineCustomOption[] = [
		{
			label: 'New window',
			description: 'Move tab to a new window',
			async execute() {
				await browser.windows.create({
					tabId: tab_id,
					focused: true,
				},);
			},
		},
	];

	for (const win of windows) {
		if (
			win.id === undefined || win.id === tab.windowId || win
				.incognito !== tab.incognito
		) { continue; }

		const id = win.id;
		const active = win.tabs?.find((tab,) => tab.active);
		options.push({
			label: active?.title || `Window ${id} `,
			description: `Window ${id}: ${win.tabs?.length ?? 0} tabs`,
			async execute() {
				await browser.tabs.move(tab_id, {
					windowId: id,
					index: -1,
				},);
			},
		},);
		options.push({
			label: `Merge into ${active?.title || `window ${id}`}`,
			description: `merge current window into window ${id}`,
			async execute() {
				const sourceTabs = await browser.tabs.query({ windowId: tab.windowId });
				const unpinned = sourceTabs.filter((t) => !t.pinned).map((t) => t.id).filter((id): id is number => id !== undefined);
				if (unpinned.length > 0) {
					await browser.tabs.move(unpinned, {
						windowId: id, index: -1
					});
				}
			}
		});
	}

	await glide.commandline.show({
		title: 'Move tab to window',
		options,
	},);
}, { description: 'Move tab to another window', },);
glide.keymaps.set('normal', '.d', 'tab_duplicate', { description: 'tab duplicate' });
glide.keymaps.set('normal', '.c', 'tab_close', { description: 'tab close' });
glide.keymaps.set('normal', '.r', 'reload', { description: 'tab reload' });
glide.keymaps.set('normal', '.f', () => {
	glide.hints.show({ location: 'browser-ui' });
}, { description: 'hint browser ui' });

// コマンド系
glide.keymaps.set('normal', '/o', async () => {
	await glide.keys.send('<C-l>', { skip_mappings: true });
}, { description: 'open url in current tab' });
glide.keymaps.set('normal', '/b', async () => {
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
glide.keymaps.set(
	'normal',
	'/c',
	async () => {
		await glide.keys.send('<C-S-l>', {
			skip_mappings: true,
		},);
	},
	{ description: 'Org Capture', },
);
