--## System ##--

export type Header = {
	sender: string,
	recipient: string,
	timestamp: number
}

export type Payload = { [string]: any }
export type ServerRequestNodePayload = {
	player: Player
}

--## Game ##--

export type MyPayload = {
	value1: boolean,
	value2: boolean
}

return {}