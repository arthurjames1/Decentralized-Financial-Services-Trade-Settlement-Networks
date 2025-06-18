;; Financial Institution Verification Contract v1
;; Validates and manages financial institutions in the network

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSTITUTION_EXISTS (err u101))
(define-constant ERR_INSTITUTION_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Institution status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map institutions
  { institution-id: principal }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    status: uint,
    verification-date: uint,
    verifier: principal
  }
)

(define-map institution-permissions
  { institution-id: principal }
  {
    can-trade: bool,
    can-settle: bool,
    max-trade-amount: uint
  }
)

;; Read-only functions
(define-read-only (get-institution (institution-id principal))
  (map-get? institutions { institution-id: institution-id })
)

(define-read-only (get-institution-permissions (institution-id principal))
  (map-get? institution-permissions { institution-id: institution-id })
)

(define-read-only (is-verified-institution (institution-id principal))
  (match (map-get? institutions { institution-id: institution-id })
    institution (is-eq (get status institution) STATUS_VERIFIED)
    false
  )
)

;; Public functions
(define-public (register-institution
  (institution-id principal)
  (name (string-ascii 100))
  (license-number (string-ascii 50))
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? institutions { institution-id: institution-id })) ERR_INSTITUTION_EXISTS)

    (map-set institutions
      { institution-id: institution-id }
      {
        name: name,
        license-number: license-number,
        status: STATUS_PENDING,
        verification-date: block-height,
        verifier: tx-sender
      }
    )

    (map-set institution-permissions
      { institution-id: institution-id }
      {
        can-trade: false,
        can-settle: false,
        max-trade-amount: u0
      }
    )

    (ok true)
  )
)

(define-public (verify-institution
  (institution-id principal)
  (max-trade-amount uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? institutions { institution-id: institution-id })) ERR_INSTITUTION_NOT_FOUND)

    (map-set institutions
      { institution-id: institution-id }
      (merge
        (unwrap-panic (map-get? institutions { institution-id: institution-id }))
        { status: STATUS_VERIFIED, verification-date: block-height }
      )
    )

    (map-set institution-permissions
      { institution-id: institution-id }
      {
        can-trade: true,
        can-settle: true,
        max-trade-amount: max-trade-amount
      }
    )

    (ok true)
  )
)

(define-public (suspend-institution (institution-id principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? institutions { institution-id: institution-id })) ERR_INSTITUTION_NOT_FOUND)

    (map-set institutions
      { institution-id: institution-id }
      (merge
        (unwrap-panic (map-get? institutions { institution-id: institution-id }))
        { status: STATUS_SUSPENDED }
      )
    )

    (map-set institution-permissions
      { institution-id: institution-id }
      (merge
        (unwrap-panic (map-get? institution-permissions { institution-id: institution-id }))
        { can-trade: false, can-settle: false }
      )
    )

    (ok true)
  )
)
