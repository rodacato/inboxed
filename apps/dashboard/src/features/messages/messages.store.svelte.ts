import type { Message } from './messages.types';

// Mock data — will be replaced with real API data in spec 002
const mockMessages: Message[] = [
	{
		id: '1',
		from: 'auth-service@cloud.io',
		fromDomain: 'cloud.io',
		subject: 'Your verification code: 8829-X',
		preview:
			'Use the following code to verify your account. This code will expire in 10 minutes...',
		time: '2m ago',
		isNew: true
	},
	{
		id: '2',
		from: 'noreply@github.com',
		fromDomain: 'github.com',
		subject: '[GitHub] Please verify your email address',
		preview:
			'Hey there! Please click the link below to verify your email address for your GitHub account...',
		time: '15m ago',
		isNew: true
	},
	{
		id: '3',
		from: 'support@stripe.com',
		fromDomain: 'stripe.com',
		subject: 'Your monthly statement is ready',
		preview:
			'The statement for the period of Feb 15 - Mar 14 is now available in your dashboard...',
		time: '1h ago',
		isNew: false
	},
	{
		id: '4',
		from: 'team@linear.app',
		fromDomain: 'linear.app',
		subject: 'Issue ARCH-122 assigned to you',
		preview:
			'The architecture review for the new messaging module is now ready for your approval...',
		time: 'Yesterday',
		isNew: false
	}
];

const messages = $state<Message[]>(mockMessages);
let selectedId = $state<string>('1');
let loading = $state(false);

export function getMessagesStore() {
	return {
		get messages() {
			return messages;
		},
		get selectedId() {
			return selectedId;
		},
		get selectedMessage() {
			return messages.find((m) => m.id === selectedId) ?? null;
		},
		get loading() {
			return loading;
		},
		select(id: string) {
			selectedId = id;
		},
		async load() {
			// Will fetch from API in spec 002
			loading = true;
			try {
				// const data = await fetchMessages();
				// messages = data;
			} finally {
				loading = false;
			}
		}
	};
}
