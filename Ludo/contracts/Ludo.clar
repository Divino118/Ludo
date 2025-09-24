;; Game Development Studio Smart Contract  
;; Description: A decentralised game development contract on Stacks. The studio lead sets a dev budget and timeline, players back the game, and features are implemented only if backers approve through voting. If the budget isn't met, backers can claim refunds.

;; Constants
(define-constant ERR_NOT_STUDIO_LEAD (err u100))
(define-constant ERR_GAME_ALREADY_IN_DEV (err u101))
(define-constant ERR_BACKER_NOT_FOUND (err u102))
(define-constant ERR_DEV_CYCLE_ENDED (err u103))
(define-constant ERR_BUDGET_TARGET_MISSED (err u104))
(define-constant ERR_INSUFFICIENT_DEV_BUDGET (err u105))
(define-constant ERR_INVALID_BACKING_AMOUNT (err u106))
(define-constant ERR_INVALID_DEV_TIMELINE (err u107))

;; Data Variables
(define-data-var studio-lead (optional principal) none)
(define-data-var development-budget uint u0)
(define-data-var funds-raised uint u0)
(define-data-var current-feature uint u0)
(define-data-var feature-approvals uint u0)
(define-data-var feature-rejections uint u0)
(define-data-var total-backers uint u0)
(define-data-var development-deadline uint u0)
(define-data-var game-phase (string-ascii 20) "not_started")

;; Maps
(define-map backer-investments principal uint)
(define-map feature-roadmap uint {description: (string-utf8 256), cost: uint})

;; Private Functions
(define-private (is-studio-lead)
  (is-eq (some tx-sender) (var-get studio-lead))
)

(define-private (is-development-active)
  (and
    (is-eq (var-get game-phase) "development")
    (<= stacks-block-height (var-get development-deadline))
  )
)

;; Public Functions
(define-public (launch-game-development (budget uint) (timeline uint))
  (begin
    (asserts! (is-none (var-get studio-lead)) ERR_GAME_ALREADY_IN_DEV)
    (asserts! (> budget u0) ERR_INVALID_BACKING_AMOUNT)
    (asserts! (and (> timeline u0) (<= timeline u52560)) ERR_INVALID_DEV_TIMELINE)
    (var-set studio-lead (some tx-sender))
    (var-set development-budget budget)
    (var-set development-deadline (+ stacks-block-height timeline))
    (var-set game-phase "development")
    (ok true)
  )
)

(define-public (back-game (amount uint))
  (let (
    (current-backing (default-to u0 (map-get? backer-investments tx-sender)))
  )
    (asserts! (is-development-active) ERR_DEV_CYCLE_ENDED)
    (asserts! (> amount u0) ERR_INVALID_BACKING_AMOUNT)
    (asserts! (<= (+ (var-get funds-raised) amount) (var-get development-budget)) ERR_BUDGET_TARGET_MISSED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set funds-raised (+ (var-get funds-raised) amount))
    (map-set backer-investments tx-sender (+ current-backing amount))
    (if (is-eq current-backing u0)
      (var-set total-backers (+ (var-get total-backers) u1))
      true
    )
    (ok true)
  )
)

(define-public (vote-on-feature (approve bool))
  (let ((investment (default-to u0 (map-get? backer-investments tx-sender))))
    (asserts! (> investment u0) ERR_BACKER_NOT_FOUND)
    (asserts! (is-eq (var-get game-phase) "playtesting") ERR_NOT_STUDIO_LEAD)
    (if approve
      (var-set feature-approvals (+ (var-get feature-approvals) investment))
      (var-set feature-rejections (+ (var-get feature-rejections) investment))
    )
    (ok true)
  )
)

(define-public (begin-playtesting-phase)
  (begin
    (asserts! (is-studio-lead) ERR_NOT_STUDIO_LEAD)
    (asserts! (is-eq (var-get game-phase) "development") ERR_NOT_STUDIO_LEAD)
    (var-set game-phase "playtesting")
    (var-set feature-approvals u0)
    (var-set feature-rejections u0)
    (ok true)
  )
)

(define-public (end-playtesting-phase)
  (begin
    (asserts! (is-studio-lead) ERR_NOT_STUDIO_LEAD)
    (asserts! (is-eq (var-get game-phase) "playtesting") ERR_NOT_STUDIO_LEAD)
    (let ((total-votes (+ (var-get feature-approvals) (var-get feature-rejections))))
      (asserts! (> total-votes u0) ERR_BACKER_NOT_FOUND)
      (if (> (var-get feature-approvals) (var-get feature-rejections))
        (begin
          (var-set current-feature (+ (var-get current-feature) u1))
          (var-set game-phase "development")
          (ok true)
        )
        (begin
          (var-set game-phase "development")
          (err u508)  ;; ERR_FEATURE_REJECTED
        )
      )
    )
  )
)

(define-public (add-game-feature (description (string-utf8 256)) (cost uint))
  (begin
    (asserts! (is-studio-lead) ERR_NOT_STUDIO_LEAD)
    (asserts! (> cost u0) ERR_INVALID_BACKING_AMOUNT)
    (asserts! (<= (len description) u256) (err u509))  ;; ERR_INVALID_FEATURE_DESC
    (map-set feature-roadmap (var-get current-feature) {description: description, cost: cost})
    (ok true)
  )
)

(define-public (withdraw-dev-funds (amount uint))
  (begin
    (asserts! (is-studio-lead) ERR_NOT_STUDIO_LEAD)
    (asserts! (> amount u0) ERR_INVALID_BACKING_AMOUNT)
    (asserts! (<= amount (var-get funds-raised)) ERR_INSUFFICIENT_DEV_BUDGET)
    (as-contract (stx-transfer? amount tx-sender (unwrap! (var-get studio-lead) ERR_BACKER_NOT_FOUND)))
  )
)

(define-public (claim-backer-refund)
  (let ((investment (default-to u0 (map-get? backer-investments tx-sender))))
    (asserts! (and
      (> stacks-block-height (var-get development-deadline))
      (< (var-get funds-raised) (var-get development-budget))
    ) ERR_NOT_STUDIO_LEAD)
    (asserts! (> investment u0) ERR_BACKER_NOT_FOUND)
    (map-delete backer-investments tx-sender)
    (as-contract (stx-transfer? investment tx-sender tx-sender))
  )
)

;; Read-only Functions
(define-read-only (get-game-status)
  (ok {
    lead: (var-get studio-lead),
    budget: (var-get development-budget),
    raised: (var-get funds-raised),
    deadline: (var-get development-deadline),
    phase: (var-get game-phase),
    current-feature: (var-get current-feature)
  })
)

(define-read-only (get-backer-investment (backer principal))
  (ok (default-to u0 (map-get? backer-investments backer)))
)

(define-read-only (get-feature-info (feature-id uint))
  (map-get? feature-roadmap feature-id)
)