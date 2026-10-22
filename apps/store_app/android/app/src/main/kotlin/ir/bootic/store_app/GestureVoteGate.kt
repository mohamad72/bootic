package ir.bootic.store_app

/** Two agreeing observations in a short window, tolerating a missed detection.
 * A held thumb never advances multiple garments: lower the hand to rearm. */
internal class GestureVoteGate {
    private var candidate: String? = null
    private var candidateSince = 0L
    private var neutralSince: Long? = null
    private var armed = true
    private var lastVote = -1000L

    fun reset() {
        candidate = null
        neutralSince = null
        armed = true
        lastVote = -1000L
    }

    fun update(label: String?, timestamp: Long, enabled: Boolean): String? {
        if (label == null) {
            if (neutralSince == null) neutralSince = timestamp
            if (timestamp - neutralSince!! >= 250) {
                armed = true
                candidate = null
            }
            return null
        }
        neutralSince = null
        if (!enabled || !armed || timestamp - lastVote < 900) {
            candidate = null
            return null
        }
        if (candidate != label || timestamp - candidateSince > 500) {
            candidate = label
            candidateSince = timestamp
            return null
        }
        candidate = null
        armed = false
        lastVote = timestamp
        return label
    }
}
