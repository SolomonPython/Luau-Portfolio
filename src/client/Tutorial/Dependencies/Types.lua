--===--===--===--===--===--===--===--===--===--===--===--===--===--
export type ITutorial = {
	--> Constructor
	new: (title: string, pages: { string }) -> (),

	--> Functions
	next: (self: ITutorial) -> (),
	prev: (self: ITutorial) -> (),
	animate: (self: ITutorial, text: string) -> (),
	open: (self: ITutorial) -> (),
	close: (self: ITutorial, onComplete: () -> ()?) -> (),
	destroy: (self: ITutorial) -> (),

	--> Variables
	title: string,
	pages: { string },
	currentPage: number,
	_animating: boolean,
}

return {}
--===--===--===--===--===--===--===--===--===--===--===--===--===--
