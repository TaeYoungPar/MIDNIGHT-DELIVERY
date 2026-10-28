--!strict
export type Phase = "WAITING" | "PREPARING" | "PLAYING" | "RESULTS"
export type Snapshot = {
	version: number, phase: Phase, roundId: number, endsAt: number,
	participant: boolean, playerCount: number, coins: number, xp: number,
	result: string, reward: number, orderActive: boolean, target: Vector3?,
}
return {}
