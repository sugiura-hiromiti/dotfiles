glide.o.native_tabs = "autohide";

glide.keymaps.set("normal", "tt", "commandline_show tab ")
glide.keymaps.set("normal", "tn", "tab_new")
glide.keymaps.set("normal", "tx", "tab_close")

glide.keymaps.set("normal", "H", "back")
glide.keymaps.set("normal", "L", "forward")

glide.keymaps.set("normal", "gb", async () => {
	const tree = await browser.bookmarks.getTree();
	const bookmarks: { title: string; url: string; }[] = [];

	function collect(nodes: typeof tree): void {
		for (const node of nodes) {
			if (node.url) {
				bookmarks.push({
					title: node.title, url: node.url,
				});
			}
			if (node.children) {
				collect(node.children);
			}
		}
	}

	collect(tree);

	await glide.commandline.show({
		title: "bookmarks",
		options: bookmarks.map(
			({ title, url }) => ({
				label: title || url,
				description: url,
				async execute() {
					await browser.tabs.create({
						url, active: true,
					});
				}
			})
		)
	})
}, { description: "Search bookmarks" },);
