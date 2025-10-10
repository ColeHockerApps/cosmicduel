import SpriteKit
import SwiftUI
import simd

// MARK: - Physics Categories
private struct Cat {
    static let none: UInt32      = 0
    static let rocket: UInt32    = 1 << 0
    static let obstacle: UInt32  = 1 << 1
    static let gate: UInt32      = 1 << 2
    static let world: UInt32     = 1 << 3
}

// MARK: - Rocket container to keep per-side state
private final class RocketAgent {
    let side: Side
    let node: SKNode
    let body: SKPhysicsBody
    var touchHolding: Bool = false
    var lastDashTime: TimeInterval = -1_000
    var alive: Bool = true

    init(side: Side, node: SKNode, body: SKPhysicsBody) {
        self.side = side
        self.node = node
        self.body = body
    }

    var canDash: Bool {
        let now = CACurrentMediaTime()
        return now - lastDashTime >= GameConstants.Rocket.dashCooldown
    }

    func didDash() {
        lastDashTime = CACurrentMediaTime()
    }
}

// MARK: - Obstacle node wrapper
private final class ObstacleNode: SKShapeNode {
    enum Kind { case asteroid, mine }
    var kind: Kind = .asteroid
    var drift: CGVector = .zero
}

// MARK: - DuelScene
final class DuelScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Dependencies
    private unowned let match: MatchState

    // MARK: - Rockets
    private var leftAgent: RocketAgent!
    private var rightAgent: RocketAgent?

    // MARK: - Spawning
    private var lastSpawn: TimeInterval = 0
    private var roundStartTime: TimeInterval = 0

    // MARK: - Touch tracking (swipes for dash)
    private var leftTouchStart: CGPoint?
    private var rightTouchStart: CGPoint?

    // MARK: - Nodes
    private let worldLayer = SKNode()
    private let starsLayer = SKNode()

    // MARK: - Lifecycle
    init(size: CGSize, match: MatchState) {
        self.match = match
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        setupWorld()
        setupStars()
        setupRockets()
        roundStartTime = CACurrentMediaTime()
        lastSpawn = roundStartTime
    }

    // MARK: - Setup
    private func setupWorld() {
        backgroundColor = ColorTokens.background.uiColor

        physicsWorld.gravity = GameConstants.Physics.gravity
        physicsWorld.contactDelegate = self

        addChild(starsLayer)
        addChild(worldLayer)

        // Edge loop
        let inset = GameConstants.Physics.worldEdgeInset
        let rect = frame.insetBy(dx: inset, dy: inset)
        physicsBody = SKPhysicsBody(edgeLoopFrom: rect)
        physicsBody?.categoryBitMask = Cat.world
        physicsBody?.collisionBitMask = Cat.rocket
        physicsBody?.contactTestBitMask = Cat.rocket
    }

    private func setupStars() {
        starsLayer.zPosition = GameConstants.Z.stars
        let starColor = GameConstants.Colors.star
        let count = GameConstants.Misc.starCount
        for _ in 0..<count {
            let n = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.6...1.6))
            n.fillColor = starColor
            n.strokeColor = .clear
            n.alpha = CGFloat.random(in: 0.35...0.9)
            n.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                 y: CGFloat.random(in: 0...size.height))
            starsLayer.addChild(n)

            let dx = -size.width - 60
            let dur = TimeInterval.random(in: GameConstants.Misc.starDriftDurationRange)
            let move = SKAction.moveBy(x: dx, y: 0, duration: dur)
            let reset = SKAction.run { [weak self, weak n] in
                guard let self, let n else { return }
                n.position.x = self.size.width + 60
                n.position.y = CGFloat.random(in: 0...self.size.height)
            }
            n.run(.repeatForever(.sequence([move, reset])))
        }
    }

    private func setupRockets() {
        // Left rocket always exists
        leftAgent = makeRocket(side: .left)

        switch match.mode {
        case .duel, .timeAttackDuel, .suddenDeath:
            rightAgent = makeRocket(side: .right)
        case .soloSurvival, .timeAttackSolo:
            rightAgent = nil
        }
    }

    // MARK: - Rocket creation with gradient shader
    private func makeRocket(side: Side) -> RocketAgent {
        let bodySize = GameConstants.Rocket.bodySize
        let physicsSize = GameConstants.Rocket.physicsSize

        // Container
        let container = SKNode()
        container.zPosition = GameConstants.Z.rockets
        let xFrac = (side == .left) ? GameConstants.Rocket.spawnXFraction : (1 - GameConstants.Rocket.spawnXFraction)
        container.position = CGPoint(x: size.width * xFrac, y: size.height * 0.5)

        // Sprite
        let sprite = SKSpriteNode(imageNamed: GameConstants.Rocket.spriteName)
        sprite.size = bodySize
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.zPosition = 0

        // Apply gradient shader (top -> bottom)
        let paint = (side == .left) ? match.leftRocketPaint : match.rightRocketPaint
        sprite.shader = makeGradientShader(paint: paint)

        // Flame (fade on thrust) — оставляем как было
        let flamePath = CGMutablePath()
        flamePath.move(to: CGPoint(x: 0, y: -bodySize.height * 0.5))
        flamePath.addLine(to: CGPoint(x: -8, y: -bodySize.height * 0.5 - 18))
        flamePath.addLine(to: CGPoint(x: 8,  y: -bodySize.height * 0.5 - 18))
        flamePath.closeSubpath()
        let flame = SKShapeNode(path: flamePath)
        flame.fillColor = GameConstants.Colors.flame
        flame.strokeColor = .clear
        flame.alpha = 0
        flame.name = "flame"

        container.addChild(sprite)
        container.addChild(flame)

        // Physics
        let phys = SKPhysicsBody(rectangleOf: physicsSize)
        phys.allowsRotation = false
        phys.categoryBitMask = Cat.rocket
        phys.collisionBitMask = Cat.world | Cat.obstacle
        phys.contactTestBitMask = Cat.world | Cat.obstacle | Cat.gate
        container.physicsBody = phys

        addChild(container)
        return RocketAgent(side: side, node: container, body: phys)
    }

    // Build a simple vertical gradient shader that multiplies the white texture
    private func makeGradientShader(paint: RocketPaint) -> SKShader {
        let src = """
        void main() {
            vec2 uv = v_tex_coord;
            vec4 tex = texture2D(u_texture, uv);
            // uv.y: 0 at bottom, 1 at top
            vec3 grad = mix(u_bottomColor.rgb, u_topColor.rgb, uv.y);
            vec4 outColor = vec4(tex.rgb * grad, tex.a);
            gl_FragColor = outColor;
        }
        """
        let shader = SKShader(source: src)
        shader.uniforms = [
            SKUniform(name: "u_topColor", vectorFloat4: paint.top.rgbaFloat4()),
            SKUniform(name: "u_bottomColor", vectorFloat4: paint.bottom.rgbaFloat4())
        ]
        return shader
    }

    // MARK: - Theme refresh on size / trait changes
    override func didChangeSize(_ oldSize: CGSize) {
        backgroundColor = ColorTokens.background.uiColor
    }

    // MARK: - Input handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard match.isPlaying else { return }
        for t in touches {
            let p = t.location(in: self)
            if p.x < size.width * 0.5 {
                leftAgent.touchHolding = true
                leftTouchStart = p
                showFlame(for: leftAgent, on: true)
                Haptics.shared.tap()
                applyThrust(agent: leftAgent)
            } else if let right = rightAgent {
                right.touchHolding = true
                rightTouchStart = p
                showFlame(for: right, on: true)
                Haptics.shared.tap()
                applyThrust(agent: right)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Swipe-to-dash detection happens in touchesEnded for clarity
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard match.isPlaying else { return }
        for t in touches {
            let p = t.location(in: self)

            if p.x < size.width * 0.5 {
                performDashIfSwipe(from: leftTouchStart, to: p, agent: leftAgent)
                leftAgent.touchHolding = false
                showFlame(for: leftAgent, on: false)
                leftTouchStart = nil
            } else if let right = rightAgent {
                performDashIfSwipe(from: rightTouchStart, to: p, agent: right)
                right.touchHolding = false
                showFlame(for: right, on: false)
                rightTouchStart = nil
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func performDashIfSwipe(from start: CGPoint?, to end: CGPoint, agent: RocketAgent) {
        guard let s = start else { return }
        let dx = end.x - s.x
        let dy = end.y - s.y
        let distance = hypot(dx, dy)
        guard distance >= GameConstants.Controls.swipeDeadZone else { return }
        guard agent.canDash else { return }

        if abs(dx) > abs(dy) && abs(dx) > GameConstants.Controls.swipeDeadZone {
            let dir: CGFloat = dx > 0 ? 1 : -1
            performDash(agent: agent, directionX: dir)
        }
    }

    // MARK: - Update loop
    override func update(_ currentTime: TimeInterval) {
        guard match.isPlaying else { return }

        // Apply thrust if holding
        if leftAgent.alive, leftAgent.touchHolding {
            applyThrust(agent: leftAgent)
        }
        if let right = rightAgent, right.alive, right.touchHolding {
            applyThrust(agent: right)
        }

        // Clamp velocities & gentle tilts
        applyFlightTilt(agent: leftAgent)
        if let right = rightAgent {
            applyFlightTilt(agent: right)
        }

        // Spawn obstacles per spawn curve
        spawnStep(time: currentTime)

        // Cleanup out-of-bounds nodes
        cleanObstaclesIfNeeded()
    }

    // MARK: - Thrust / Dash
    private func applyThrust(agent: RocketAgent) {
        guard agent.alive else { return }
        agent.body.applyImpulse(GameConstants.Rocket.thrustImpulse)
        agent.node.run(.rotate(toAngle: GameConstants.Rocket.tiltUp,
                               duration: GameConstants.Rocket.tiltDurationUp,
                               shortestUnitArc: true))
        showFlame(for: agent, on: true)
    }

    private func applyFlightTilt(agent: RocketAgent) {
        guard agent.alive else { return }
        let v = agent.body.velocity
        let clampedY = max(min(v.dy, GameConstants.Physics.maxVelocityY), GameConstants.Physics.minVelocityY)
        if clampedY != v.dy {
            agent.body.velocity = CGVector(dx: v.dx, dy: clampedY)
        }
        if !agent.touchHolding {
            agent.node.run(.rotate(toAngle: GameConstants.Rocket.tiltDown,
                                   duration: GameConstants.Rocket.tiltDurationDown,
                                   shortestUnitArc: true))
            showFlame(for: agent, on: false)
        }
    }

    private func performDash(agent: RocketAgent, directionX: CGFloat) {
        performDash(agent: agent, rawDeltaX: directionX * GameConstants.Rocket.dashImpulseX)
    }

    private func performDash(agent: RocketAgent, rawDeltaX: CGFloat) {
        guard agent.canDash, agent.alive else { return }
        agent.didDash()
        let body = agent.body
        body.applyImpulse(CGVector(dx: rawDeltaX, dy: 0))
        Haptics.shared.impactMediumFeedback()

        let nudge = SKAction.moveBy(x: rawDeltaX * 0.06, y: 0, duration: GameConstants.Rocket.dashDurationVisual)
        nudge.timingMode = .easeOut
        agent.node.run(nudge)
    }

    private func showFlame(for agent: RocketAgent, on: Bool) {
        if let flame = agent.node.childNode(withName: "flame") as? SKShapeNode {
            flame.run(.fadeAlpha(to: on ? 1.0 : 0.0, duration: 0.08))
        }
    }

    // MARK: - Spawning
    private func spawnStep(time currentTime: TimeInterval) {
        let since = currentTime - lastSpawn
        let progress: Double
        if let p = match.roundProgress {
            progress = p
        } else {
            let elapsed = currentTime - roundStartTime
            progress = max(0, min(1, elapsed / 60.0))
        }

        let rules = match.rules
        let interval = rules.spawn.interval(at: progress)
        guard since >= interval else { return }
        lastSpawn = currentTime

        let currentObstacles = worldLayer.children.compactMap { $0 as? ObstacleNode }.count
        if currentObstacles >= min(rules.spawn.maxSimultaneous, GameConstants.Spawn.absoluteMaxSimultaneous) {
            return
        }

        let count = (progress > 0.65) ? 2 : 1
        for _ in 0..<count { spawnObstacle() }

        if match.mode == .timeAttackSolo || match.mode == .timeAttackDuel {
            spawnGate()
        }
    }

    private func spawnObstacle() {
        let isMine = (Int.random(in: 0..<5) == 0) // 20%
        if isMine { spawnMine() } else { spawnAsteroid() }
    }

    private func spawnAsteroid() {
        let w = CGFloat.random(in: GameConstants.Obstacles.asteroidMinSize.width...GameConstants.Obstacles.asteroidMaxSize.width)
        let h = CGFloat.random(in: GameConstants.Obstacles.asteroidMinSize.height...GameConstants.Obstacles.asteroidMaxSize.height)
        let node = ObstacleNode(rectOf: CGSize(width: w, height: h), cornerRadius: min(w, h) * 0.18)
        node.kind = .asteroid
        node.fillColor = Bool.random() ? GameConstants.Colors.asteroidA : GameConstants.Colors.asteroidB
        node.strokeColor = .clear
        node.zPosition = GameConstants.Z.obstacles

        let fromLeft = Bool.random()
        let x = fromLeft ? (size.width + GameConstants.Obstacles.spawnOffsetX) : (-GameConstants.Obstacles.spawnOffsetX)
        let y = CGFloat.random(in: GameConstants.Spawn.verticalSafeMargin...(size.height - GameConstants.Spawn.verticalSafeMargin))
        node.position = CGPoint(x: x, y: y)

        node.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: w, height: h))
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = Cat.obstacle
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.contactTestBitMask = Cat.rocket

        var speed = GameConstants.Obstacles.baseDriftSpeed + CGFloat.random(in: -GameConstants.Obstacles.driftRandomness...GameConstants.Obstacles.driftRandomness)
        speed *= fromLeft ? -1 : 1
        node.drift = CGVector(dx: speed, dy: 0)

        let distance = size.width + GameConstants.Obstacles.spawnOffsetX * 2 + w
        let duration = TimeInterval(abs(distance / speed))
        let move = SKAction.moveBy(x: node.drift.dx * duration, y: 0, duration: duration)
        let rotate = SKAction.rotate(byAngle: CGFloat.random(in: GameConstants.Obstacles.asteroidAngularVelocityRange) * CGFloat(duration),
                                     duration: duration)
        node.run(.group([move, rotate])) { [weak node] in node?.removeFromParent() }

        worldLayer.addChild(node)
    }

    private func spawnMine() {
        let sz = GameConstants.Obstacles.mineSize
        let node = ObstacleNode(circleOfRadius: sz.width * 0.5)
        node.kind = .mine
        node.fillColor = GameConstants.Colors.mine
        node.strokeColor = .clear
        node.zPosition = GameConstants.Z.obstacles

        let fromLeft = Bool.random()
        let x = fromLeft ? (size.width + GameConstants.Obstacles.spawnOffsetX) : (-GameConstants.Obstacles.spawnOffsetX)
        let y = CGFloat.random(in: GameConstants.Spawn.verticalSafeMargin...(size.height - GameConstants.Spawn.verticalSafeMargin))
        node.position = CGPoint(x: x, y: y)

        node.physicsBody = SKPhysicsBody(circleOfRadius: sz.width * 0.5)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = Cat.obstacle
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.contactTestBitMask = Cat.rocket

        var speed = GameConstants.Obstacles.baseDriftSpeed + CGFloat.random(in: -GameConstants.Obstacles.driftRandomness...GameConstants.Obstacles.driftRandomness)
        speed *= fromLeft ? -1 : 1
        node.drift = CGVector(dx: speed, dy: 0)

        let distance = size.width + GameConstants.Obstacles.spawnOffsetX * 2 + sz.width
        let duration = TimeInterval(abs(distance / speed))
        let move = SKAction.moveBy(x: node.drift.dx * duration, y: 0, duration: duration)
        node.run(move) { [weak node] in node?.removeFromParent() }

        worldLayer.addChild(node)
    }

    private func spawnGate() {
        let gate = SKNode()
        gate.name = "gate"
        gate.zPosition = GameConstants.Z.gates

        let w = GameConstants.Obstacles.gateWidth
        let h = size.height
        gate.position = CGPoint(x: size.width + GameConstants.Obstacles.spawnOffsetX + 15,
                                y: size.height * 0.5)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: w, height: h))
        body.isDynamic = false
        body.categoryBitMask = Cat.gate
        body.collisionBitMask = 0
        body.contactTestBitMask = Cat.rocket
        gate.physicsBody = body

        let speed = -GameConstants.Obstacles.baseDriftSpeed
        let distance = size.width + GameConstants.Obstacles.spawnOffsetX * 2
        let duration = TimeInterval(abs(distance / speed))
        let move = SKAction.moveBy(x: speed * CGFloat(duration), y: 0, duration: duration)
        gate.run(move) { [weak gate] in gate?.removeFromParent() }

        worldLayer.addChild(gate)
    }

    // MARK: - Cleanup
    private func cleanObstaclesIfNeeded() {
        let margin: CGFloat = 200
        worldLayer.children.forEach { node in
            if node.position.x < -margin || node.position.x > size.width + margin {
                if !(node is SKNode && node.name == "gate") {
                    node.removeFromParent()
                }
            }
        }
    }

    // MARK: - Contacts
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB

        if (a.categoryBitMask == Cat.gate && b.categoryBitMask == Cat.rocket) ||
           (b.categoryBitMask == Cat.gate && a.categoryBitMask == Cat.rocket) {
            handleGateContact(rocketBody: (a.categoryBitMask == Cat.rocket ? a : b))
            return
        }

        if (a.categoryBitMask == Cat.rocket && (b.categoryBitMask == Cat.obstacle || b.categoryBitMask == Cat.world)) ||
           (b.categoryBitMask == Cat.rocket && (a.categoryBitMask == Cat.obstacle || a.categoryBitMask == Cat.world)) {
            handleRocketHit(rocketBody: (a.categoryBitMask == Cat.rocket ? a : b),
                            otherBody: (a.categoryBitMask == Cat.rocket ? b : a))
            return
        }
    }

    private func handleGateContact(rocketBody: SKPhysicsBody) {
        guard match.mode == .timeAttackSolo || match.mode == .timeAttackDuel else { return }
        guard let node = rocketBody.node else { return }

        let side: Side = (node == leftAgent.node) ? .left : .right
        let amount = match.rules.scoring.gateScore
        match.addScore(to: side, amount: amount)

        let pop = SKAction.sequence([
            .scale(to: GameConstants.Scoring.scorePopScale, duration: GameConstants.Scoring.scorePopDuration),
            .scale(to: 1.0, duration: GameConstants.Scoring.scorePopDuration)
        ])
        node.run(pop)
    }

    private func handleRocketHit(rocketBody: SKPhysicsBody, otherBody: SKPhysicsBody) {
        guard let node = rocketBody.node else { return }

        if let obs = otherBody.node as? ObstacleNode, obs.kind == .mine {
            rocketBody.applyImpulse(GameConstants.Obstacles.mineKnockback)
            node.run(.rotate(byAngle: GameConstants.Obstacles.mineAngularNudge, duration: 0.08))
            Haptics.shared.impactHeavyFeedback()
        }

        if match.rules.oneHit {
            kill(node: node)
        } else {
            kill(node: node)
        }
    }

    private func kill(node: SKNode) {
        Haptics.shared.error()

        if node == leftAgent.node {
            leftAgent.alive = false
            explode(at: node.position)
            node.removeFromParent()
        } else if let right = rightAgent, node == right.node {
            right.alive = false
            explode(at: node.position)
            node.removeFromParent()
        }

        evaluateRoundEndIfNeeded()
    }

    private func explode(at pos: CGPoint) {
        let boom = SKShapeNode(circleOfRadius: 18)
        boom.fillColor = GameConstants.Colors.mine
        boom.strokeColor = .clear
        boom.position = pos
        boom.zPosition = GameConstants.Z.effects
        addChild(boom)
        boom.run(.sequence([
            .group([
                .scale(to: 2.2, duration: 0.18),
                .fadeOut(withDuration: 0.18)
            ]),
            .removeFromParent()
        ]))
    }

    private func evaluateRoundEndIfNeeded() {
        switch match.mode {
        case .soloSurvival, .timeAttackSolo:
            if !leftAgent.alive {
                match.endRound(winner: .solo)
            }
        case .duel, .timeAttackDuel, .suddenDeath:
            let leftAlive = leftAgent.alive
            let rightAlive = rightAgent?.alive ?? false

            if !leftAlive && !rightAlive {
                match.endRound(winner: .tie)
            } else if !leftAlive {
                match.endRound(winner: .right)
            } else if !rightAlive {
                match.endRound(winner: .left)
            }
        }
    }

    // MARK: - Public API (called by GameView for restarts)
    func resetRoundForRematch() {
        removeAllActions()
        removeAllChildren()
        starsLayer.removeAllChildren()
        worldLayer.removeAllChildren()

        setupWorld()
        setupStars()
        setupRockets()
        leftTouchStart = nil
        rightTouchStart = nil
        roundStartTime = CACurrentMediaTime()
        lastSpawn = roundStartTime
    }
}

// MARK: - UIColor helpers
private extension UIColor {
    func rgbaFloat4() -> vector_float4 {
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return vector_float4(Float(r), Float(g), Float(b), Float(a))
    }
}
