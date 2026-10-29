--!strict
export type Phase = "WAITING" | "PREPARING" | "PLAYING" | "RESULTS"
export type Snapshot = {
	level: number, data: { mode: string, reason: string, dirty: boolean }, owned: { [string]: boolean }, equipped: { [string]: string },
	vehicle: { owned: boolean, seated: boolean, speed: number, resetAt: number }, stamina: number,
	downUntil: number, protectedUntil: number, members: { { name: string, downUntil: number } },
	chase: { kind: string, targetId: number, endsAt: number },
	version: number, phase: Phase, roundId: number, endsAt: number,
	participant: boolean, playerCount: number, coins: number, xp: number,
	result: string, reward: number, orderActive: boolean, target: Vector3?,
	orderIndex: number, orderTitle: string, orderHint: string, orderEndsAt: number,
	stage: string, knocks: number, holdUntil: number, cooldownUntil: number,
	hotUntil: number, late: boolean, successes: number, failures: number,
}
return {}
