;; vendor-registration
;; Smart contract for registering and managing farmers market vendors
;; Handles vendor applications, verification, and profile management

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_VENDOR_EXISTS (err u101))
(define-constant ERR_VENDOR_NOT_FOUND (err u102))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u103))
(define-constant ERR_INVALID_STATUS (err u104))
(define-constant ERR_INVALID_NAME (err u105))
(define-constant ERR_INVALID_DESCRIPTION (err u106))
(define-constant REGISTRATION_FEE u1000000) ;; 1 STX in microstx
(define-constant MIN_NAME_LENGTH u2)
(define-constant MAX_NAME_LENGTH u64)
(define-constant MIN_DESC_LENGTH u10)
(define-constant MAX_DESC_LENGTH u256)

;; Data Variables
(define-data-var next-vendor-id uint u1)
(define-data-var total-vendors uint u0)
(define-data-var contract-admin principal CONTRACT_OWNER)

;; Data Maps
(define-map vendors
  { vendor-id: uint }
  {
    owner: principal,
    name: (string-ascii 64),
    description: (string-ascii 256),
    certification: (string-ascii 32),
    products: (list 10 (string-ascii 32)),
    verified: bool,
    registration-date: uint,
    performance-score: uint,
    status: (string-ascii 16),
    application-fee-paid: uint
  }
)

(define-map vendor-by-owner
  { owner: principal }
  { vendor-id: uint }
)

(define-map vendor-certifications
  { vendor-id: uint }
  { 
    organic-certified: bool,
    local-certified: bool,
    artisan-certified: bool,
    certification-date: uint
  }
)

(define-map vendor-applications
  { application-id: uint }
  {
    vendor-id: uint,
    application-date: uint,
    review-status: (string-ascii 16),
    reviewer: (optional principal),
    notes: (string-ascii 256)
  }
)

;; Private Functions
(define-private (is-contract-admin (user principal))
  (is-eq user (var-get contract-admin))
)

(define-private (is-vendor-owner (vendor-id uint) (user principal))
  (match (map-get? vendors { vendor-id: vendor-id })
    vendor (is-eq (get owner vendor) user)
    false
  )
)

(define-private (validate-vendor-name (name (string-ascii 64)))
  (let ((name-len (len name)))
    (and 
      (>= name-len MIN_NAME_LENGTH)
      (<= name-len MAX_NAME_LENGTH)
    )
  )
)

(define-private (validate-vendor-description (description (string-ascii 256)))
  (let ((desc-len (len description)))
    (and 
      (>= desc-len MIN_DESC_LENGTH)
      (<= desc-len MAX_DESC_LENGTH)
    )
  )
)

(define-private (calculate-performance-score (vendor-id uint))
  ;; Simple performance calculation - can be enhanced
  u75 ;; Default score
)

;; Read-only Functions
(define-read-only (get-vendor-info (vendor-id uint))
  (map-get? vendors { vendor-id: vendor-id })
)

(define-read-only (get-vendor-by-owner (owner principal))
  (match (map-get? vendor-by-owner { owner: owner })
    vendor-ref (map-get? vendors { vendor-id: (get vendor-id vendor-ref) })
    none
  )
)

(define-read-only (get-vendor-certifications (vendor-id uint))
  (map-get? vendor-certifications { vendor-id: vendor-id })
)

(define-read-only (get-total-vendors)
  (var-get total-vendors)
)

(define-read-only (get-registration-fee)
  REGISTRATION_FEE
)

(define-read-only (is-vendor-verified (vendor-id uint))
  (match (map-get? vendors { vendor-id: vendor-id })
    vendor (get verified vendor)
    false
  )
)

(define-read-only (get-vendor-status (vendor-id uint))
  (match (map-get? vendors { vendor-id: vendor-id })
    vendor (some (get status vendor))
    none
  )
)

;; Public Functions
(define-public (register-vendor 
  (name (string-ascii 64))
  (description (string-ascii 256))
  (certification (string-ascii 32))
  (products (list 10 (string-ascii 32)))
)
  (let (
    (vendor-id (var-get next-vendor-id))
    (caller tx-sender)
  )
    ;; Input validation
    (asserts! (validate-vendor-name name) ERR_INVALID_NAME)
    (asserts! (validate-vendor-description description) ERR_INVALID_DESCRIPTION)
    
    ;; Check if vendor already exists
    (asserts! (is-none (map-get? vendor-by-owner { owner: caller })) ERR_VENDOR_EXISTS)
    
    ;; Process registration fee payment
    (try! (stx-transfer? REGISTRATION_FEE caller (var-get contract-admin)))
    
    ;; Create vendor record
    (map-set vendors 
      { vendor-id: vendor-id }
      {
        owner: caller,
        name: name,
        description: description,
        certification: certification,
        products: products,
        verified: false,
        registration-date: stacks-block-height,
        performance-score: u50, ;; Initial score
        status: "pending",
        application-fee-paid: REGISTRATION_FEE
      }
    )
    
    ;; Create owner mapping
    (map-set vendor-by-owner
      { owner: caller }
      { vendor-id: vendor-id }
    )
    
    ;; Initialize certifications
    (map-set vendor-certifications
      { vendor-id: vendor-id }
      {
        organic-certified: false,
        local-certified: false,
        artisan-certified: false,
        certification-date: u0
      }
    )
    
    ;; Update counters
    (var-set next-vendor-id (+ vendor-id u1))
    (var-set total-vendors (+ (var-get total-vendors) u1))
    
    (ok vendor-id)
  )
)

(define-public (verify-vendor (vendor-id uint) (approved bool))
  (let (
    (caller tx-sender)
  )
    ;; Only admin can verify vendors
    (asserts! (is-contract-admin caller) ERR_UNAUTHORIZED)
    
    ;; Check vendor exists
    (match (map-get? vendors { vendor-id: vendor-id })
      vendor 
      (begin
        ;; Update verification status
        (map-set vendors
          { vendor-id: vendor-id }
          (merge vendor {
            verified: approved,
            status: (if approved "verified" "rejected"),
            performance-score: (if approved u75 (get performance-score vendor))
          })
        )
        (ok approved)
      )
      ERR_VENDOR_NOT_FOUND
    )
  )
)

(define-public (update-vendor-profile
  (vendor-id uint)
  (name (string-ascii 64))
  (description (string-ascii 256))
  (products (list 10 (string-ascii 32)))
)
  (let (
    (caller tx-sender)
  )
    ;; Validate inputs
    (asserts! (validate-vendor-name name) ERR_INVALID_NAME)
    (asserts! (validate-vendor-description description) ERR_INVALID_DESCRIPTION)
    
    ;; Check authorization
    (asserts! (is-vendor-owner vendor-id caller) ERR_UNAUTHORIZED)
    
    ;; Update vendor profile
    (match (map-get? vendors { vendor-id: vendor-id })
      vendor
      (begin
        (map-set vendors
          { vendor-id: vendor-id }
          (merge vendor {
            name: name,
            description: description,
            products: products
          })
        )
        (ok true)
      )
      ERR_VENDOR_NOT_FOUND
    )
  )
)

(define-public (update-vendor-status (vendor-id uint) (new-status (string-ascii 16)))
  (let (
    (caller tx-sender)
  )
    ;; Only admin can update status
    (asserts! (is-contract-admin caller) ERR_UNAUTHORIZED)
    
    ;; Update vendor status
    (match (map-get? vendors { vendor-id: vendor-id })
      vendor
      (begin
        (map-set vendors
          { vendor-id: vendor-id }
          (merge vendor { status: new-status })
        )
        (ok new-status)
      )
      ERR_VENDOR_NOT_FOUND
    )
  )
)

(define-public (add-certification (vendor-id uint) (cert-type (string-ascii 16)))
  (let (
    (caller tx-sender)
  )
    ;; Only admin can add certifications
    (asserts! (is-contract-admin caller) ERR_UNAUTHORIZED)
    
    ;; Check vendor exists and is verified
    (asserts! (is-vendor-verified vendor-id) ERR_VENDOR_NOT_FOUND)
    
    ;; Update certifications based on type
    (match (map-get? vendor-certifications { vendor-id: vendor-id })
      certs
      (begin
        (if (is-eq cert-type "organic")
          (map-set vendor-certifications
            { vendor-id: vendor-id }
            (merge certs {
              organic-certified: true,
              certification-date: stacks-block-height
            })
          )
          (if (is-eq cert-type "local")
            (map-set vendor-certifications
              { vendor-id: vendor-id }
              (merge certs {
                local-certified: true,
                certification-date: stacks-block-height
              })
            )
            (if (is-eq cert-type "artisan")
              (map-set vendor-certifications
                { vendor-id: vendor-id }
                (merge certs {
                  artisan-certified: true,
                  certification-date: stacks-block-height
                })
              )
              false
            )
          )
        )
        (ok true)
      )
      ERR_VENDOR_NOT_FOUND
    )
  )
)

(define-public (update-performance-score (vendor-id uint) (new-score uint))
  (let (
    (caller tx-sender)
  )
    ;; Only admin can update performance scores
    (asserts! (is-contract-admin caller) ERR_UNAUTHORIZED)
    ;; Score should be between 0 and 100
    (asserts! (and (<= new-score u100) (>= new-score u0)) ERR_INVALID_STATUS)
    
    ;; Update performance score
    (match (map-get? vendors { vendor-id: vendor-id })
      vendor
      (begin
        (map-set vendors
          { vendor-id: vendor-id }
          (merge vendor { performance-score: new-score })
        )
        (ok new-score)
      )
      ERR_VENDOR_NOT_FOUND
    )
  )
)

(define-public (set-contract-admin (new-admin principal))
  (begin
    (asserts! (is-contract-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set contract-admin new-admin)
    (ok new-admin)
  )
)

