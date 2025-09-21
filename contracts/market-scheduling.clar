;; market-scheduling
;; Smart contract for coordinating farmers market events and booth assignments
;; Manages market scheduling, vendor booth allocation, and event coordination

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_MARKET_EXISTS (err u201))
(define-constant ERR_MARKET_NOT_FOUND (err u202))
(define-constant ERR_MARKET_FULL (err u203))
(define-constant ERR_INVALID_DATE (err u204))
(define-constant ERR_BOOTH_OCCUPIED (err u205))
(define-constant ERR_VENDOR_NOT_REGISTERED (err u206))
(define-constant ERR_INVALID_LOCATION (err u207))
(define-constant ERR_MARKET_CANCELLED (err u208))
(define-constant ERR_BOOTH_NOT_FOUND (err u209))
(define-constant MIN_LOCATION_LENGTH u5)
(define-constant MAX_LOCATION_LENGTH u64)
(define-constant MAX_VENDORS_PER_MARKET u100)
(define-constant BOOTH_ASSIGNMENT_FEE u500000) ;; 0.5 STX in microstx

;; Data Variables
(define-data-var next-market-id uint u1)
(define-data-var next-booth-id uint u1)
(define-data-var total-markets uint u0)
(define-data-var contract-admin principal CONTRACT_OWNER)

;; Data Maps
(define-map market-events
  { market-id: uint }
  {
    date: uint,
    location: (string-ascii 64),
    max-vendors: uint,
    registered-count: uint,
    status: (string-ascii 16),
    organizer: principal,
    creation-date: uint,
    booth-fee: uint,
    setup-time: uint,
    duration-hours: uint
  }
)

(define-map booth-assignments
  { booth-id: uint }
  {
    market-id: uint,
    vendor-id: uint,
    booth-number: uint,
    assigned-date: uint,
    assignment-fee-paid: uint,
    status: (string-ascii 16),
    preferences: (string-ascii 64)
  }
)

(define-map market-vendors
  { market-id: uint, vendor-id: uint }
  {
    booth-id: uint,
    registration-date: uint,
    confirmed: bool,
    payment-status: (string-ascii 16)
  }
)

(define-map vendor-preferences
  { vendor-id: uint }
  {
    preferred-locations: (list 5 (string-ascii 32)),
    booth-size-preference: (string-ascii 16),
    special-requirements: (string-ascii 128),
    availability-days: (list 7 uint)
  }
)

(define-map market-schedules
  { schedule-id: uint }
  {
    market-id: uint,
    recurring-pattern: (string-ascii 16),
    frequency: uint,
    end-date: uint,
    active: bool
  }
)

;; Private Functions
(define-private (is-contract-admin (user principal))
  (is-eq user (var-get contract-admin))
)

(define-private (is-market-organizer (market-id uint) (user principal))
  (match (map-get? market-events { market-id: market-id })
    market (is-eq (get organizer market) user)
    false
  )
)

(define-private (validate-location (location (string-ascii 64)))
  (let ((location-len (len location)))
    (and 
      (>= location-len MIN_LOCATION_LENGTH)
      (<= location-len MAX_LOCATION_LENGTH)
    )
  )
)

(define-private (validate-future-date (date uint))
  (> date stacks-block-height)
)

(define-private (is-booth-available (market-id uint) (booth-number uint))
  ;; For simplicity, always return true - in production would check actual booth availability
  ;; Could be enhanced by maintaining a map of occupied booths per market
  true
)

(define-private (get-market-booth-numbers (market-id uint))
  ;; Returns list of occupied booth numbers for a market
  ;; Simplified implementation - could be enhanced with proper indexing
  (list)
)

(define-private (calculate-booth-assignment-score (vendor-id uint) (market-id uint))
  ;; Algorithm to fairly assign booths based on various factors
  ;; Could include vendor history, preferences, payment promptness, etc.
  u50 ;; Default score
)

;; Read-only Functions
(define-read-only (get-market-info (market-id uint))
  (map-get? market-events { market-id: market-id })
)

(define-read-only (get-booth-assignment (booth-id uint))
  (map-get? booth-assignments { booth-id: booth-id })
)

(define-read-only (get-vendor-booth (market-id uint) (vendor-id uint))
  (map-get? market-vendors { market-id: market-id, vendor-id: vendor-id })
)

(define-read-only (get-vendor-preferences (vendor-id uint))
  (map-get? vendor-preferences { vendor-id: vendor-id })
)

(define-read-only (get-total-markets)
  (var-get total-markets)
)

(define-read-only (is-market-full (market-id uint))
  (match (map-get? market-events { market-id: market-id })
    market (>= (get registered-count market) (get max-vendors market))
    true
  )
)

(define-read-only (get-market-availability (market-id uint))
  (match (map-get? market-events { market-id: market-id })
    market 
    (some {
      available-spots: (- (get max-vendors market) (get registered-count market)),
      max-vendors: (get max-vendors market),
      registered-count: (get registered-count market)
    })
    none
  )
)

(define-read-only (get-booth-fee (market-id uint))
  (match (map-get? market-events { market-id: market-id })
    market (some (get booth-fee market))
    none
  )
)

;; Public Functions
(define-public (create-market-event
  (date uint)
  (location (string-ascii 64))
  (max-vendors uint)
  (booth-fee uint)
  (setup-time uint)
  (duration-hours uint)
)
  (let (
    (market-id (var-get next-market-id))
    (caller tx-sender)
  )
    ;; Input validation
    (asserts! (validate-location location) ERR_INVALID_LOCATION)
    (asserts! (validate-future-date date) ERR_INVALID_DATE)
    (asserts! (and (> max-vendors u0) (<= max-vendors MAX_VENDORS_PER_MARKET)) ERR_MARKET_FULL)
    (asserts! (> duration-hours u0) ERR_INVALID_DATE)
    
    ;; Only admin or authorized organizers can create markets
    (asserts! (is-contract-admin caller) ERR_UNAUTHORIZED)
    
    ;; Create market event
    (map-set market-events
      { market-id: market-id }
      {
        date: date,
        location: location,
        max-vendors: max-vendors,
        registered-count: u0,
        status: "scheduled",
        organizer: caller,
        creation-date: stacks-block-height,
        booth-fee: booth-fee,
        setup-time: setup-time,
        duration-hours: duration-hours
      }
    )
    
    ;; Update counters
    (var-set next-market-id (+ market-id u1))
    (var-set total-markets (+ (var-get total-markets) u1))
    
    (ok market-id)
  )
)

(define-public (assign-booth
  (market-id uint)
  (vendor-id uint)
  (booth-number uint)
  (preferences (string-ascii 64))
)
  (let (
    (booth-id (var-get next-booth-id))
    (caller tx-sender)
  )
    ;; Check market exists and is not full
    (asserts! (is-some (map-get? market-events { market-id: market-id })) ERR_MARKET_NOT_FOUND)
    (asserts! (not (is-market-full market-id)) ERR_MARKET_FULL)
    
    ;; Only admin or market organizer can assign booths
    (asserts! (or (is-contract-admin caller) (is-market-organizer market-id caller)) ERR_UNAUTHORIZED)
    
    ;; Check booth availability
    (asserts! (is-booth-available market-id booth-number) ERR_BOOTH_OCCUPIED)
    
    ;; Get booth fee for this market
    (match (get-booth-fee market-id)
      fee-amount
      (begin
        ;; Process booth assignment fee
        (try! (stx-transfer? fee-amount caller (var-get contract-admin)))
        
        ;; Create booth assignment
        (map-set booth-assignments
          { booth-id: booth-id }
          {
            market-id: market-id,
            vendor-id: vendor-id,
            booth-number: booth-number,
            assigned-date: stacks-block-height,
            assignment-fee-paid: fee-amount,
            status: "assigned",
            preferences: preferences
          }
        )
        
        ;; Register vendor for market
        (map-set market-vendors
          { market-id: market-id, vendor-id: vendor-id }
          {
            booth-id: booth-id,
            registration-date: stacks-block-height,
            confirmed: true,
            payment-status: "paid"
          }
        )
        
        ;; Update market registered count
        (match (map-get? market-events { market-id: market-id })
          market
          (map-set market-events
            { market-id: market-id }
            (merge market {
              registered-count: (+ (get registered-count market) u1)
            })
          )
          false
        )
        
        ;; Update counters
        (var-set next-booth-id (+ booth-id u1))
        
        (ok booth-id)
      )
      ERR_MARKET_NOT_FOUND
    )
  )
)

(define-public (update-booth-assignment
  (booth-id uint)
  (new-booth-number uint)
  (new-preferences (string-ascii 64))
)
  (let (
    (caller tx-sender)
  )
    ;; Check booth exists
    (match (map-get? booth-assignments { booth-id: booth-id })
      booth
      (let (
        (market-id (get market-id booth))
      )
        ;; Only admin or market organizer can update assignments
        (asserts! (or (is-contract-admin caller) (is-market-organizer market-id caller)) ERR_UNAUTHORIZED)
        
        ;; Check new booth availability (if changing booth number)
        (asserts! (or (is-eq new-booth-number (get booth-number booth)) 
                     (is-booth-available market-id new-booth-number)) ERR_BOOTH_OCCUPIED)
        
        ;; Update booth assignment
        (map-set booth-assignments
          { booth-id: booth-id }
          (merge booth {
            booth-number: new-booth-number,
            preferences: new-preferences
          })
        )
        
        (ok true)
      )
      ERR_BOOTH_NOT_FOUND
    )
  )
)

(define-public (cancel-market-event (market-id uint))
  (let (
    (caller tx-sender)
  )
    ;; Check market exists
    (match (map-get? market-events { market-id: market-id })
      market
      (begin
        ;; Only admin or market organizer can cancel
        (asserts! (or (is-contract-admin caller) (is-market-organizer market-id caller)) ERR_UNAUTHORIZED)
        
        ;; Update market status to cancelled
        (map-set market-events
          { market-id: market-id }
          (merge market { status: "cancelled" })
        )
        
        (ok true)
      )
      ERR_MARKET_NOT_FOUND
    )
  )
)

(define-public (set-vendor-preferences
  (vendor-id uint)
  (preferred-locations (list 5 (string-ascii 32)))
  (booth-size-preference (string-ascii 16))
  (special-requirements (string-ascii 128))
  (availability-days (list 7 uint))
)
  (let (
    (caller tx-sender)
  )
    ;; For now, allow any caller to set preferences for any vendor
    ;; In production, you might want to restrict this to vendor owners
    
    (map-set vendor-preferences
      { vendor-id: vendor-id }
      {
        preferred-locations: preferred-locations,
        booth-size-preference: booth-size-preference,
        special-requirements: special-requirements,
        availability-days: availability-days
      }
    )
    
    (ok true)
  )
)

(define-public (confirm-booth-assignment (booth-id uint))
  (let (
    (caller tx-sender)
  )
    ;; Check booth exists
    (match (map-get? booth-assignments { booth-id: booth-id })
      booth
      (let (
        (market-id (get market-id booth))
        (vendor-id (get vendor-id booth))
      )
        ;; Update confirmation status
        (match (map-get? market-vendors { market-id: market-id, vendor-id: vendor-id })
          vendor-record
          (begin
            (map-set market-vendors
              { market-id: market-id, vendor-id: vendor-id }
              (merge vendor-record { confirmed: true })
            )
            (ok true)
          )
          ERR_VENDOR_NOT_REGISTERED
        )
      )
      ERR_BOOTH_NOT_FOUND
    )
  )
)

(define-public (update-market-status (market-id uint) (new-status (string-ascii 16)))
  (let (
    (caller tx-sender)
  )
    ;; Only admin can update market status
    (asserts! (is-contract-admin caller) ERR_UNAUTHORIZED)
    
    ;; Update market status
    (match (map-get? market-events { market-id: market-id })
      market
      (begin
        (map-set market-events
          { market-id: market-id }
          (merge market { status: new-status })
        )
        (ok new-status)
      )
      ERR_MARKET_NOT_FOUND
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

