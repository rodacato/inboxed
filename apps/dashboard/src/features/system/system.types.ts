export type ConnectionStatus = 'checking...' | 'connected' | 'disconnected' | 'error';

export interface SystemStatus {
	service: string;
	version: string;
	status: string;
	environment?: string;
	database?: string;
	redis?: string;
}
