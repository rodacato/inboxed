export interface Message {
	id: string;
	from: string;
	fromDomain: string;
	subject: string;
	preview: string;
	time: string;
	isNew: boolean;
	bodyHtml?: string;
	bodyText?: string;
}
