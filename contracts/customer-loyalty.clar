;; customer-loyalty
;; Smart contract for tracking customer purchases and managing loyalty rewards
;; Implements point-based reward system across participating vendors

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_CUSTOMER_NOT_FOUND (err u301))
(define-constant ERR_INSUFFICIENT_POINTS (err u302))
(define-constant ERR_INVALID_AMOUNT (err u303))
(define-constant ERR_VENDOR_NOT_VERIFIED (err u304))
(define-constant ERR_REWARD_NOT_FOUND (err u305))
(define-constant ERR_INVALID_TIER (err u306))
(define-constant ERR_CUSTOMER_EXISTS (err u307))
(define-constant POINTS_PER_STX u100) ;; 100 points per 1 STX spent
(define-constant BRONZE_TIER_THRESHOLD u1000)
(define-constant SILVER_TIER_THRESHOLD u5000)
(define-constant GOLD_TIER_THRESHOLD u15000)
(define-constant PLATINUM_TIER_THRESHOLD u50000)
(define-constant MAX_REWARD_PERCENTAGE u50) ;; Maximum 50% discount

;; Data Variables
(define-data-var next-transaction-id uint u1)
(define-data-var next-reward-id uint u1)
(define-data-var total-customers uint u0)
(define-data-var total-points-issued uint u0)
(define-data-var contract-admin principal CONTRACT_OWNER)

;; Data Maps
(define-map customers
  { customer: principal }
  {
    total-purchases: uint,
    loyalty-points: uint,
    tier-level: uint,
    join-date: uint,
    last-activity: uint,
    lifetime-spent: uint,
    transactions-count: uint
  }
)

(define-map customer-transactions
  { transaction-id: uint }
  {
    customer: principal,
    vendor-id: uint,
    amount: uint,
    points-earned: uint,
    transaction-date: uint,
    market-id: uint,
    transaction-type: (string-ascii 16)
  }
)

(define-map loyalty-rewards
  { reward-id: uint }
  {
    name: (string-ascii 64),
    description: (string-ascii 256),
    points-required: uint,
    discount-percentage: uint,
    valid-until: uint,
    max-uses: uint,
    current-uses: uint,
    vendor-id: (optional uint),
    active: bool
  }
)

(define-map customer-rewards
  { customer: principal, reward-id: uint }
  {
    redeemed-date: uint,
    used: bool,
    expires: uint
  }
)

(define-map tier-benefits
  { tier-level: uint }
  {
    tier-name: (string-ascii 16),
    points-multiplier: uint,
    special-discounts: uint,
    priority-access: bool,
    exclusive-events: bool
  }
)

(define-map vendor-customer-history
  { vendor-id: uint, customer: principal }
  {
    first-purchase: uint,
    last-purchase: uint,
    total-spent: uint,
    purchase-count: uint,
    favorite-customer: bool
  }
)

;; Private Functions
(define-private (is-contract-admin (user principal))
  (is-eq user (var-get contract-admin))
)

(define-private (calculate-points (amount uint))
  (* amount POINTS_PER_STX)
)

(define-private (calculate-tier (total-points uint))
  (if (>= total-points PLATINUM_TIER_THRESHOLD)
    u4 ;; Platinum
    (if (>= total-points GOLD_TIER_THRESHOLD)
      u3 ;; Gold
      (if (>= total-points SILVER_TIER_THRESHOLD)
        u2 ;; Silver
        (if (>= total-points BRONZE_TIER_THRESHOLD)
          u1 ;; Bronze
          u0 ;; Basic
        )
      )
    )
  )
)

(define-private (get-tier-multiplier (tier uint))
  (if (is-eq tier u4)
    u200 ;; Platinum: 2x points
    (if (is-eq tier u3)
      u150 ;; Gold: 1.5x points
      (if (is-eq tier u2)
        u125 ;; Silver: 1.25x points
        (if (is-eq tier u1)
          u110 ;; Bronze: 1.1x points
          u100 ;; Basic: 1x points
        )
      )
    )
  )
)

(define-private (apply-tier-bonus (base-points uint) (tier uint))
  (/ (* base-points (get-tier-multiplier tier)) u100)
)

;; Read-only Functions
(define-read-only (get-customer-info (customer principal))
  (map-get? customers { customer: customer })
)

(define-read-only (get-customer-points (customer principal))
  (match (map-get? customers { customer: customer })
    customer-data (some (get loyalty-points customer-data))
    none
  )
)

(define-read-only (get-customer-tier (customer principal))
  (match (map-get? customers { customer: customer })
    customer-data (some (get tier-level customer-data))
    (some u0) ;; Default to basic tier
  )
)

(define-read-only (get-transaction-info (transaction-id uint))
  (map-get? customer-transactions { transaction-id: transaction-id })
)

(define-read-only (get-reward-info (reward-id uint))
  (map-get? loyalty-rewards { reward-id: reward-id })
)

(define-read-only (get-customer-reward-status (customer principal) (reward-id uint))
  (map-get? customer-rewards { customer: customer, reward-id: reward-id })
)

(define-read-only (get-total-customers)
  (var-get total-customers)
)

(define-read-only (get-total-points-issued)
  (var-get total-points-issued)
)

(define-read-only (calculate-reward-points (amount uint) (customer principal))
  (let (
    (base-points (calculate-points amount))
    (customer-tier (unwrap! (get-customer-tier customer) u0))
  )
    (apply-tier-bonus base-points customer-tier)
  )
)

(define-read-only (get-vendor-customer-stats (vendor-id uint) (customer principal))
  (map-get? vendor-customer-history { vendor-id: vendor-id, customer: customer })
)

;; Public Functions
(define-public (register-customer)
  (let (
    (caller tx-sender)
  )
    ;; Check if customer already exists
    (asserts! (is-none (map-get? customers { customer: caller })) ERR_CUSTOMER_EXISTS)
    
    ;; Create customer account
    (map-set customers
      { customer: caller }
      {
        total-purchases: u0,
        loyalty-points: u0,
        tier-level: u0,
        join-date: stacks-block-height,
        last-activity: stacks-block-height,
        lifetime-spent: u0,
        transactions-count: u0
      }
    )
    
    ;; Update total customers
    (var-set total-customers (+ (var-get total-customers) u1))
    
    (ok true)
  )
)

(define-public (record-purchase
  (customer principal)
  (vendor-id uint)
  (amount uint)
  (market-id uint)
)
  (let (
    (transaction-id (var-get next-transaction-id))
    (caller tx-sender)
  )
    ;; Input validation
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Check customer exists, if not auto-register
    (match (map-get? customers { customer: customer })
      customer-data
      (let (
        (base-points (calculate-points amount))
        (current-tier (get tier-level customer-data))
        (bonus-points (apply-tier-bonus base-points current-tier))
        (new-total-spent (+ (get lifetime-spent customer-data) amount))
        (new-total-points (+ (get loyalty-points customer-data) bonus-points))
        (new-tier (calculate-tier new-total-points))
      )
        ;; Update customer record
        (map-set customers
          { customer: customer }
          (merge customer-data {
            total-purchases: (+ (get total-purchases customer-data) amount),
            loyalty-points: new-total-points,
            tier-level: new-tier,
            last-activity: stacks-block-height,
            lifetime-spent: new-total-spent,
            transactions-count: (+ (get transactions-count customer-data) u1)
          })
        )
        
        ;; Record transaction
        (map-set customer-transactions
          { transaction-id: transaction-id }
          {
            customer: customer,
            vendor-id: vendor-id,
            amount: amount,
            points-earned: bonus-points,
            transaction-date: stacks-block-height,
            market-id: market-id,
            transaction-type: "purchase"
          }
        )
        
        ;; Update vendor-customer history
        (match (map-get? vendor-customer-history { vendor-id: vendor-id, customer: customer })
          history
          (map-set vendor-customer-history
            { vendor-id: vendor-id, customer: customer }
            (merge history {
              last-purchase: stacks-block-height,
              total-spent: (+ (get total-spent history) amount),
              purchase-count: (+ (get purchase-count history) u1)
            })
          )
          ;; Create new history record
          (map-set vendor-customer-history
            { vendor-id: vendor-id, customer: customer }
            {
              first-purchase: stacks-block-height,
              last-purchase: stacks-block-height,
              total-spent: amount,
              purchase-count: u1,
              favorite-customer: false
            }
          )
        )
        
        ;; Update counters
        (var-set next-transaction-id (+ transaction-id u1))
        (var-set total-points-issued (+ (var-get total-points-issued) bonus-points))
        
        (ok transaction-id)
      )
      ;; Auto-register customer if they don't exist  
      (begin
        (map-set customers
          { customer: customer }
          {
            total-purchases: amount,
            loyalty-points: (calculate-points amount),
            tier-level: u0,
            join-date: stacks-block-height,
            last-activity: stacks-block-height,
            lifetime-spent: amount,
            transactions-count: u1
          }
        )
        
        ;; Record transaction for new customer
        (map-set customer-transactions
          { transaction-id: transaction-id }
          {
            customer: customer,
            vendor-id: vendor-id,
            amount: amount,
            points-earned: (calculate-points amount),
            transaction-date: stacks-block-height,
            market-id: market-id,
            transaction-type: "purchase"
          }
        )
        
        ;; Create vendor-customer history for new customer
        (map-set vendor-customer-history
          { vendor-id: vendor-id, customer: customer }
          {
            first-purchase: stacks-block-height,
            last-purchase: stacks-block-height,
            total-spent: amount,
            purchase-count: u1,
            favorite-customer: false
          }
        )
        
        ;; Update counters
        (var-set next-transaction-id (+ transaction-id u1))
        (var-set total-points-issued (+ (var-get total-points-issued) (calculate-points amount)))
        (var-set total-customers (+ (var-get total-customers) u1))
        
        (ok transaction-id)
      )
    )
  )
)

(define-public (redeem-points
  (customer principal)
  (points-to-redeem uint)
  (vendor-id (optional uint))
)
  (let (
    (caller tx-sender)
  )
    ;; Check customer exists and has sufficient points
    (match (map-get? customers { customer: customer })
      customer-data
      (begin
        (asserts! (>= (get loyalty-points customer-data) points-to-redeem) ERR_INSUFFICIENT_POINTS)
        
        ;; Deduct points
        (map-set customers
          { customer: customer }
          (merge customer-data {
            loyalty-points: (- (get loyalty-points customer-data) points-to-redeem),
            last-activity: stacks-block-height
          })
        )
        
        ;; Record redemption transaction
        (map-set customer-transactions
          { transaction-id: (var-get next-transaction-id) }
          {
            customer: customer,
            vendor-id: (default-to u0 vendor-id),
            amount: u0,
            points-earned: (- points-to-redeem), ;; Negative to show redemption
            transaction-date: stacks-block-height,
            market-id: u0,
            transaction-type: "redemption"
          }
        )
        
        (var-set next-transaction-id (+ (var-get next-transaction-id) u1))
        
        (ok points-to-redeem)
      )
      ERR_CUSTOMER_NOT_FOUND
    )
  )
)

(define-public (create-loyalty-reward
  (name (string-ascii 64))
  (description (string-ascii 256))
  (points-required uint)
  (discount-percentage uint)
  (valid-until uint)
  (max-uses uint)
  (vendor-id (optional uint))
)
  (let (
    (reward-id (var-get next-reward-id))
    (caller tx-sender)
  )
    ;; Only admin can create rewards
    (asserts! (is-contract-admin caller) ERR_UNAUTHORIZED)
    (asserts! (<= discount-percentage MAX_REWARD_PERCENTAGE) ERR_INVALID_AMOUNT)
    
    ;; Create reward
    (map-set loyalty-rewards
      { reward-id: reward-id }
      {
        name: name,
        description: description,
        points-required: points-required,
        discount-percentage: discount-percentage,
        valid-until: valid-until,
        max-uses: max-uses,
        current-uses: u0,
        vendor-id: vendor-id,
        active: true
      }
    )
    
    (var-set next-reward-id (+ reward-id u1))
    
    (ok reward-id)
  )
)

(define-public (redeem-reward (customer principal) (reward-id uint))
  (let (
    (caller tx-sender)
  )
    ;; Check reward exists and is active
    (match (map-get? loyalty-rewards { reward-id: reward-id })
      reward
      (begin
        (asserts! (get active reward) ERR_REWARD_NOT_FOUND)
        (asserts! (< (get current-uses reward) (get max-uses reward)) ERR_REWARD_NOT_FOUND)
        (asserts! (> (get valid-until reward) stacks-block-height) ERR_REWARD_NOT_FOUND)
        
        ;; Check customer has sufficient points
        (match (map-get? customers { customer: customer })
          customer-data
          (begin
            (asserts! (>= (get loyalty-points customer-data) (get points-required reward)) ERR_INSUFFICIENT_POINTS)
            
            ;; Deduct points and record redemption
            (try! (redeem-points customer (get points-required reward) (get vendor-id reward)))
            
            ;; Record customer reward redemption
            (map-set customer-rewards
              { customer: customer, reward-id: reward-id }
              {
                redeemed-date: stacks-block-height,
                used: false,
                expires: (get valid-until reward)
              }
            )
            
            ;; Update reward usage count
            (map-set loyalty-rewards
              { reward-id: reward-id }
              (merge reward {
                current-uses: (+ (get current-uses reward) u1)
              })
            )
            
            (ok true)
          )
          ERR_CUSTOMER_NOT_FOUND
        )
      )
      ERR_REWARD_NOT_FOUND
    )
  )
)

(define-public (update-customer-tier (customer principal))
  (let (
    (caller tx-sender)
  )
    ;; Check customer exists
    (match (map-get? customers { customer: customer })
      customer-data
      (let (
        (current-points (get loyalty-points customer-data))
        (new-tier (calculate-tier current-points))
      )
        ;; Update tier if changed
        (if (not (is-eq (get tier-level customer-data) new-tier))
          (begin
            (map-set customers
              { customer: customer }
              (merge customer-data {
                tier-level: new-tier,
                last-activity: stacks-block-height
              })
            )
            (ok new-tier)
          )
          (ok (get tier-level customer-data))
        )
      )
      ERR_CUSTOMER_NOT_FOUND
    )
  )
)

(define-public (set-tier-benefits
  (tier-level uint)
  (tier-name (string-ascii 16))
  (points-multiplier uint)
  (special-discounts uint)
  (priority-access bool)
  (exclusive-events bool)
)
  (let (
    (caller tx-sender)
  )
    ;; Only admin can set tier benefits
    (asserts! (is-contract-admin caller) ERR_UNAUTHORIZED)
    (asserts! (<= tier-level u4) ERR_INVALID_TIER)
    
    (map-set tier-benefits
      { tier-level: tier-level }
      {
        tier-name: tier-name,
        points-multiplier: points-multiplier,
        special-discounts: special-discounts,
        priority-access: priority-access,
        exclusive-events: exclusive-events
      }
    )
    
    (ok true)
  )
)

(define-public (set-contract-admin (new-admin principal))
  (begin
    (asserts! (is-contract-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set contract-admin new-admin)
    (ok new-admin)
  )
)

