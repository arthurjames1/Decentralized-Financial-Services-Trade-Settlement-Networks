;; Collateral Management Contract v1
;; Manages trade collateral for settlement security

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u401))
(define-constant ERR_COLLATERAL_NOT_FOUND (err u402))
(define-constant ERR_COLLATERAL_LOCKED (err u403))

;; Collateral status
(define-constant COLLATERAL_STATUS_AVAILABLE u1)
(define-constant COLLATERAL_STATUS_LOCKED u2)
(define-constant COLLATERAL_STATUS_RELEASED u3)

;; Data structures
(define-map collateral-accounts
  { institution: principal }
  {
    total-deposited: uint,
    available-amount: uint,
    locked-amount: uint,
    last-updated: uint
  }
)

(define-map collateral-locks
  { lock-id: uint }
  {
    institution: principal,
    settlement-id: uint,
    locked-amount: uint,
    status: uint,
    locked-at: uint,
    released-at: (optional uint)
  }
)

(define-data-var next-lock-id uint u1)

;; Read-only functions
(define-read-only (get-collateral-account (institution principal))
  (map-get? collateral-accounts { institution: institution })
)

(define-read-only (get-collateral-lock (lock-id uint))
  (map-get? collateral-locks { lock-id: lock-id })
)

(define-read-only (get-available-collateral (institution principal))
  (match (map-get? collateral-accounts { institution: institution })
    account (get available-amount account)
    u0
  )
)

;; Public functions
(define-public (deposit-collateral (amount uint))
  (let
    (
      (current-account (default-to
        { total-deposited: u0, available-amount: u0, locked-amount: u0, last-updated: u0 }
        (map-get? collateral-accounts { institution: tx-sender })
      ))
    )
    (asserts! (> amount u0) ERR_INSUFFICIENT_COLLATERAL)

    (map-set collateral-accounts
      { institution: tx-sender }
      {
        total-deposited: (+ (get total-deposited current-account) amount),
        available-amount: (+ (get available-amount current-account) amount),
        locked-amount: (get locked-amount current-account),
        last-updated: block-height
      }
    )

    (ok true)
  )
)

(define-public (lock-collateral
  (institution principal)
  (settlement-id uint)
  (amount uint)
)
  (let
    (
      (lock-id (var-get next-lock-id))
      (account (unwrap! (map-get? collateral-accounts { institution: institution }) ERR_COLLATERAL_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (>= (get available-amount account) amount) ERR_INSUFFICIENT_COLLATERAL)

    ;; Update account balances
    (map-set collateral-accounts
      { institution: institution }
      (merge account {
        available-amount: (- (get available-amount account) amount),
        locked-amount: (+ (get locked-amount account) amount),
        last-updated: block-height
      })
    )

    ;; Create lock record
    (map-set collateral-locks
      { lock-id: lock-id }
      {
        institution: institution,
        settlement-id: settlement-id,
        locked-amount: amount,
        status: COLLATERAL_STATUS_LOCKED,
        locked-at: block-height,
        released-at: none
      }
    )

    (var-set next-lock-id (+ lock-id u1))
    (ok lock-id)
  )
)

(define-public (release-collateral (lock-id uint))
  (let
    (
      (lock (unwrap! (map-get? collateral-locks { lock-id: lock-id }) ERR_COLLATERAL_NOT_FOUND))
      (account (unwrap! (map-get? collateral-accounts { institution: (get institution lock) }) ERR_COLLATERAL_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status lock) COLLATERAL_STATUS_LOCKED) ERR_COLLATERAL_LOCKED)

    ;; Update account balances
    (map-set collateral-accounts
      { institution: (get institution lock) }
      (merge account {
        available-amount: (+ (get available-amount account) (get locked-amount lock)),
        locked-amount: (- (get locked-amount account) (get locked-amount lock)),
        last-updated: block-height
      })
    )

    ;; Update lock status
    (map-set collateral-locks
      { lock-id: lock-id }
      (merge lock {
        status: COLLATERAL_STATUS_RELEASED,
        released-at: (some block-height)
      })
    )

    (ok true)
  )
)

(define-public (withdraw-collateral (amount uint))
  (let
    (
      (account (unwrap! (map-get? collateral-accounts { institution: tx-sender }) ERR_COLLATERAL_NOT_FOUND))
    )
    (asserts! (>= (get available-amount account) amount) ERR_INSUFFICIENT_COLLATERAL)

    (map-set collateral-accounts
      { institution: tx-sender }
      (merge account {
        total-deposited: (- (get total-deposited account) amount),
        available-amount: (- (get available-amount account) amount),
        last-updated: block-height
      })
    )

    (ok true)
  )
)
