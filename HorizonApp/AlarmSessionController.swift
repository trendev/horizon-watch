import HorizonCore
import WatchKit

/// Lifecycle of the persistent alarm: a `WKExtendedRuntimeSession` of the smart alarm kind,
/// the only way for a watchOS app to keep vibrating until stopped.
///
/// watchOS allows one scheduled session at a time, at most 36 hours ahead, and only lets the
/// app schedule it while it is in the foreground.
final class AlarmSessionController: NSObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?
    private(set) var armedID: String?

    /// The session reached its start date: the alarm rings now.
    var onStart: (() -> Void)?
    /// The session is over. `failed` is true when it never started.
    var onEnd: ((_ failed: Bool) -> Void)?
    /// Haptic to repeat while ringing, read when the session starts.
    var haptic: () -> WKHapticType = { .notification }

    private var hasStarted = false

    var isRinging: Bool { hasStarted && session?.state == .running }

    /// Schedules the session for an occurrence. Call with the app in the foreground.
    func arm(id: String, at date: Date) {
        if armedID == id, let session, session.state == .scheduled || session.state == .running { return }
        discard()
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        self.session = session
        armedID = id
        hasStarted = false
        session.start(at: date)
    }

    func disarm() {
        discard()
    }

    /// Stop, from the in-app alarm screen.
    func stop() {
        session?.invalidate()
    }

    /// watchOS relaunched the app to deliver a session scheduled by a previous launch.
    func adopt(_ session: WKExtendedRuntimeSession, id: String?) {
        guard session !== self.session else { return }
        discard()
        session.delegate = self
        self.session = session
        armedID = id
    }

    private func discard() {
        let old = session
        session = nil
        armedID = nil
        hasStarted = false
        // The delegate is cleared first so that replacing a session is not reported as its end.
        old?.delegate = nil
        old?.invalidate()
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        guard extendedRuntimeSession === session else { return }
        hasStarted = true
        let haptic = haptic()
        extendedRuntimeSession.notifyUser(hapticType: haptic) { next in
            next.pointee = haptic
            return 2
        }
        onStart?()
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?
    ) {
        guard extendedRuntimeSession === session else { return }
        let failed = !hasStarted
        session = nil
        armedID = nil
        hasStarted = false
        onEnd?(failed)
    }
}
