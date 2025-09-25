;;; ===================================================
;;; CARBONCHAIN - DECENTRALIZED CARBON CREDIT TRADING
;;; ===================================================
;;; A blockchain-based carbon credit marketplace inspired by the rapid growth
;;; of the voluntary carbon market from $4.04B in 2024 to projected $23.99B 
;;; by 2030, addressing fraud and transparency issues in traditional carbon markets.
;;;
;;; This contract enables verified carbon offset projects to mint tradeable
;;; carbon credits, companies to purchase offsets, and provides transparent
;;; tracking of environmental impact with automated retirement mechanisms.
;;; ===================================================

;; ===================================================
;; CONSTANTS AND ERROR CODES
;; ===================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-PROJECT (err u201))
(define-constant ERR-PROJECT-EXISTS (err u202))
(define-constant ERR-PROJECT-NOT-FOUND (err u203))
(define-constant ERR-INSUFFICIENT-CREDITS (err u204))
(define-constant ERR-INVALID-AMOUNT (err u205))
(define-constant ERR-TRANSFER-FAILED (err u206))
(define-constant ERR-PROJECT-NOT-VERIFIED (err u207))
(define-constant ERR-CREDITS-RETIRED (err u208))
(define-constant ERR-INVALID-VERIFICATION-STATUS (err u209))
(define-constant ERR-VERIFIER-EXISTS (err u210))
(define-constant ERR-INVALID-VERIFIER (err u211))
(define-constant ERR-INSUFFICIENT-STAKE (err u212))
(define-constant ERR-TRADING-PAUSED (err u213))
(define-constant ERR-INVALID-PRICE (err u214))
(define-constant ERR-ORDER-NOT-FOUND (err u215))
(define-constant ERR-CANNOT-FILL-OWN-ORDER (err u216))

;; Project types for different offset categories
(define-constant PROJECT-TYPE-FOREST u1)
(define-constant PROJECT-TYPE-RENEWABLE u2)
(define-constant PROJECT-TYPE-METHANE u3)
(define-constant PROJECT-TYPE-SOIL u4)
(define-constant PROJECT-TYPE-DIRECT-AIR u5)

;; Verification standards
(define-constant STANDARD-VCS u1)
(define-constant STANDARD-GOLD u2)
(define-constant STANDARD-CDM u3)
(define-constant STANDARD-PLAN-VIVO u4)

;; Minimum stakes and fees
(define-constant MIN-PROJECT-STAKE u5000000) ;; 5 STX
(define-constant MIN-VERIFIER-STAKE u10000000) ;; 10 STX
(define-constant TRADING-FEE-RATE u25) ;; 0.25% (25/10000)
(define-constant RETIREMENT-FEE u100000) ;; 0.1 STX

;; ===================================================
;; DATA STRUCTURES
;; ===================================================

;; Carbon offset projects registry
(define-map carbon-projects
    { project-id: uint }
    {
        developer: principal,
        project-name: (string-ascii 100),
        location: (string-ascii 50),
        project-type: uint,
        verification-standard: uint,
        total-credits-issued: uint,
        available-credits: uint,
        retired-credits: uint,
        price-per-credit: uint,
        registration-height: uint,
        last-updated: uint,
        is-verified: bool,
        is-active: bool,
        methodology: (string-ascii 200),
        vintage-year: uint,
        stake-amount: uint
    }
)

;; Carbon credit balances for each user per project
(define-map credit-balances
    { holder: principal, project-id: uint }
    { balance: uint }
)

;; Retired credits for tracking permanent offsets
(define-map retired-credits
    { retirement-id: uint }
    {
        retiree: principal,
        project-id: uint,
        amount: uint,
        retirement-date: uint,
        retirement-reason: (string-ascii 200),
        certificate-hash: (buff 32)
    }
)

;; Verified carbon credit verifiers (third-party auditors)
(define-map authorized-verifiers
    { verifier: principal }
    {
        organization: (string-ascii 100),
        certification-standard: uint,
        projects-verified: uint,
        registration-date: uint,
        stake-amount: uint,
        is-active: bool,
        reputation-score: uint
    }
)

;; Trading orders for carbon credit marketplace
(define-map trading-orders
    { order-id: uint }
    {
        seller: principal,
        project-id: uint,
        amount: uint,
        price-per-credit: uint,
        total-value: uint,
        created-at: uint,
        expires-at: uint,
        is-active: bool,
        filled-amount: uint
    }
)

;; Transaction history for transparency
(define-map transaction-history
    { tx-id: uint }
    {
        buyer: principal,
        seller: principal,
        project-id: uint,
        amount: uint,
        price: uint,
        timestamp: uint,
        transaction-type: (string-ascii 20)
    }
)

;; ===================================================
;; DATA VARIABLES
;; ===================================================

(define-data-var next-project-id uint u1)
(define-data-var next-retirement-id uint u1)
(define-data-var next-order-id uint u1)
(define-data-var next-transaction-id uint u1)
(define-data-var total-credits-issued uint u0)
(define-data-var total-credits-retired uint u0)
(define-data-var trading-enabled bool true)
(define-data-var platform-fee-balance uint u0)

;; ===================================================
;; PRIVATE FUNCTIONS
;; ===================================================

;; Calculate trading fee
(define-private (calculate-fee (amount uint))
    (/ (* amount TRADING-FEE-RATE) u10000)
)

;; Update transaction history
(define-private (record-transaction 
    (buyer principal) 
    (seller principal) 
    (project-id uint) 
    (amount uint) 
    (price uint) 
    (tx-type (string-ascii 20)))
    (let (
        (tx-id (var-get next-transaction-id))
    )
    (map-set transaction-history
        { tx-id: tx-id }
        {
            buyer: buyer,
            seller: seller,
            project-id: project-id,
            amount: amount,
            price: price,
            timestamp: stacks-block-height,
            transaction-type: tx-type
        }
    )
    (var-set next-transaction-id (+ tx-id u1))
    tx-id
    )
)

;; Validate project parameters
(define-private (is-valid-project-type (project-type uint))
    (or (is-eq project-type PROJECT-TYPE-FOREST)
        (or (is-eq project-type PROJECT-TYPE-RENEWABLE)
            (or (is-eq project-type PROJECT-TYPE-METHANE)
                (or (is-eq project-type PROJECT-TYPE-SOIL)
                    (is-eq project-type PROJECT-TYPE-DIRECT-AIR)))))
)

(define-private (is-valid-standard (standard uint))
    (or (is-eq standard STANDARD-VCS)
        (or (is-eq standard STANDARD-GOLD)
            (or (is-eq standard STANDARD-CDM)
                (is-eq standard STANDARD-PLAN-VIVO))))
)

;; Get user's credit balance for a project
(define-private (get-balance (user principal) (project-id uint))
    (default-to u0 (get balance (map-get? credit-balances { holder: user, project-id: project-id })))
)

;; Update user's credit balance
(define-private (set-balance (user principal) (project-id uint) (new-balance uint))
    (map-set credit-balances
        { holder: user, project-id: project-id }
        { balance: new-balance }
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - VERIFIER MANAGEMENT
;; ===================================================

;; Register as an authorized verifier
(define-public (register-verifier 
    (organization (string-ascii 100))
    (certification-standard uint)
    (stake-amount uint))
    
    (begin
        (asserts! (>= stake-amount MIN-VERIFIER-STAKE) ERR-INSUFFICIENT-STAKE)
        (asserts! (is-valid-standard certification-standard) ERR-INVALID-VERIFICATION-STATUS)
        (asserts! (is-none (map-get? authorized-verifiers { verifier: tx-sender })) ERR-VERIFIER-EXISTS)
        
        ;; Transfer stake to contract
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
        
        ;; Register verifier
        (map-set authorized-verifiers
            { verifier: tx-sender }
            {
                organization: organization,
                certification-standard: certification-standard,
                projects-verified: u0,
                registration-date: stacks-block-height,
                stake-amount: stake-amount,
                is-active: true,
                reputation-score: u100
            }
        )
        
        (ok true)
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - PROJECT MANAGEMENT
;; ===================================================

;; Register a new carbon offset project
(define-public (register-project
    (project-name (string-ascii 100))
    (location (string-ascii 50))
    (project-type uint)
    (verification-standard uint)
    (methodology (string-ascii 200))
    (vintage-year uint)
    (stake-amount uint))
    
    (let (
        (project-id (var-get next-project-id))
        (current-height stacks-block-height)
    )
    
    (asserts! (is-valid-project-type project-type) ERR-INVALID-PROJECT)
    (asserts! (is-valid-standard verification-standard) ERR-INVALID-VERIFICATION-STATUS)
    (asserts! (>= stake-amount MIN-PROJECT-STAKE) ERR-INSUFFICIENT-STAKE)
    (asserts! (> vintage-year u2020) ERR-INVALID-AMOUNT) ;; Reasonable vintage year check
    
    ;; Transfer stake to contract
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    ;; Register project
    (map-set carbon-projects
        { project-id: project-id }
        {
            developer: tx-sender,
            project-name: project-name,
            location: location,
            project-type: project-type,
            verification-standard: verification-standard,
            total-credits-issued: u0,
            available-credits: u0,
            retired-credits: u0,
            price-per-credit: u0,
            registration-height: current-height,
            last-updated: current-height,
            is-verified: false,
            is-active: false,
            methodology: methodology,
            vintage-year: vintage-year,
            stake-amount: stake-amount
        }
    )
    
    (var-set next-project-id (+ project-id u1))
    (ok project-id)
    )
)

;; Verify project by authorized verifier
(define-public (verify-project (project-id uint))
    (let (
        (project-data (unwrap! (map-get? carbon-projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
        (verifier-data (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR-INVALID-VERIFIER))
    )
    
    (asserts! (get is-active verifier-data) ERR-INVALID-VERIFIER)
    (asserts! (not (get is-verified project-data)) ERR-PROJECT-NOT-VERIFIED)
    
    ;; Update project verification status
    (map-set carbon-projects
        { project-id: project-id }
        (merge project-data {
            is-verified: true,
            is-active: true,
            last-updated: stacks-block-height
        })
    )
    
    ;; Update verifier statistics
    (map-set authorized-verifiers
        { verifier: tx-sender }
        (merge verifier-data {
            projects-verified: (+ (get projects-verified verifier-data) u1),
            reputation-score: (+ (get reputation-score verifier-data) u10)
        })
    )
    
    (ok true)
    )
)

;; Issue carbon credits for verified project
(define-public (issue-credits (project-id uint) (amount uint) (price-per-credit uint))
    (let (
        (project-data (unwrap! (map-get? carbon-projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
        (current-balance (get-balance tx-sender project-id))
    )
    
    (asserts! (is-eq tx-sender (get developer project-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-verified project-data) ERR-PROJECT-NOT-VERIFIED)
    (asserts! (get is-active project-data) ERR-PROJECT-NOT-VERIFIED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> price-per-credit u0) ERR-INVALID-PRICE)
    
    ;; Update project data
    (map-set carbon-projects
        { project-id: project-id }
        (merge project-data {
            total-credits-issued: (+ (get total-credits-issued project-data) amount),
            available-credits: (+ (get available-credits project-data) amount),
            price-per-credit: price-per-credit,
            last-updated: stacks-block-height
        })
    )
    
    ;; Update developer's balance
    (set-balance tx-sender project-id (+ current-balance amount))
    
    ;; Update global statistics
    (var-set total-credits-issued (+ (var-get total-credits-issued) amount))
    
    ;; Record transaction
    (record-transaction tx-sender tx-sender project-id amount u0 "ISSUANCE")
    
    (ok amount)
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - TRADING SYSTEM
;; ===================================================

;; Create sell order for carbon credits
(define-public (create-sell-order 
    (project-id uint) 
    (amount uint) 
    (price-per-credit uint) 
    (duration-blocks uint))
    
    (let (
        (order-id (var-get next-order-id))
        (seller-balance (get-balance tx-sender project-id))
        (total-value (* amount price-per-credit))
        (expires-at (+ stacks-block-height duration-blocks))
    )
    
    (asserts! (var-get trading-enabled) ERR-TRADING-PAUSED)
    (asserts! (>= seller-balance amount) ERR-INSUFFICIENT-CREDITS)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> price-per-credit u0) ERR-INVALID-PRICE)
    
    ;; Lock credits by reducing seller's balance
    (set-balance tx-sender project-id (- seller-balance amount))
    
    ;; Create order
    (map-set trading-orders
        { order-id: order-id }
        {
            seller: tx-sender,
            project-id: project-id,
            amount: amount,
            price-per-credit: price-per-credit,
            total-value: total-value,
            created-at: stacks-block-height,
            expires-at: expires-at,
            is-active: true,
            filled-amount: u0
        }
    )
    
    (var-set next-order-id (+ order-id u1))
    (ok order-id)
    )
)

;; Buy carbon credits from sell order
(define-public (buy-credits (order-id uint) (amount uint))
    (let (
        (order-data (unwrap! (map-get? trading-orders { order-id: order-id }) ERR-ORDER-NOT-FOUND))
        (available-amount (- (get amount order-data) (get filled-amount order-data)))
        (purchase-amount (if (> amount available-amount) available-amount amount))
        (total-cost (* purchase-amount (get price-per-credit order-data)))
        (fee (calculate-fee total-cost))
        (seller-payment (- total-cost fee))
        (buyer-balance (get-balance tx-sender (get project-id order-data)))
        (seller (get seller order-data))
        (project-id (get project-id order-data))
    )
    
    (asserts! (var-get trading-enabled) ERR-TRADING-PAUSED)
    (asserts! (get is-active order-data) ERR-ORDER-NOT-FOUND)
    (asserts! (< stacks-block-height (get expires-at order-data)) ERR-ORDER-NOT-FOUND)
    (asserts! (> available-amount u0) ERR-INSUFFICIENT-CREDITS)
    (asserts! (not (is-eq tx-sender seller)) ERR-CANNOT-FILL-OWN-ORDER)
    
    ;; Transfer payment to seller and fee to platform
    (try! (stx-transfer? seller-payment tx-sender seller))
    (try! (stx-transfer? fee tx-sender (as-contract tx-sender)))
    
    ;; Update buyer's balance
    (set-balance tx-sender project-id (+ buyer-balance purchase-amount))
    
    ;; Update order filled amount
    (let (
        (new-filled-amount (+ (get filled-amount order-data) purchase-amount))
        (is-fully-filled (is-eq new-filled-amount (get amount order-data)))
    )
    
    (map-set trading-orders
        { order-id: order-id }
        (merge order-data {
            filled-amount: new-filled-amount,
            is-active: (not is-fully-filled)
        })
    )
    
    ;; If not fully filled, return unsold credits to seller
    (if (not is-fully-filled)
        (let (
            (unsold-amount (- (get amount order-data) new-filled-amount))
            (seller-balance (get-balance seller project-id))
        )
        (set-balance seller project-id (+ seller-balance unsold-amount))
        true
        )
        true
    )
    )
    
    ;; Update platform fee balance
    (var-set platform-fee-balance (+ (var-get platform-fee-balance) fee))
    
    ;; Record transaction
    (record-transaction tx-sender seller project-id purchase-amount (get price-per-credit order-data) "PURCHASE")
    
    (ok purchase-amount)
    )
)

;; Cancel active sell order
(define-public (cancel-order (order-id uint))
    (let (
        (order-data (unwrap! (map-get? trading-orders { order-id: order-id }) ERR-ORDER-NOT-FOUND))
        (seller (get seller order-data))
        (unfilled-amount (- (get amount order-data) (get filled-amount order-data)))
        (seller-balance (get-balance seller (get project-id order-data)))
    )
    
    (asserts! (is-eq tx-sender seller) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active order-data) ERR-ORDER-NOT-FOUND)
    
    ;; Return unsold credits to seller
    (set-balance seller (get project-id order-data) (+ seller-balance unfilled-amount))
    
    ;; Deactivate order
    (map-set trading-orders
        { order-id: order-id }
        (merge order-data { is-active: false })
    )
    
    (ok unfilled-amount)
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - CARBON RETIREMENT
;; ===================================================

;; Permanently retire carbon credits (offset)
(define-public (retire-credits 
    (project-id uint) 
    (amount uint) 
    (retirement-reason (string-ascii 200))
    (certificate-hash (buff 32)))
    
    (let (
        (retirement-id (var-get next-retirement-id))
        (user-balance (get-balance tx-sender project-id))
        (project-data (unwrap! (map-get? carbon-projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
    )
    
    (asserts! (>= user-balance amount) ERR-INSUFFICIENT-CREDITS)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer retirement fee
    (try! (stx-transfer? RETIREMENT-FEE tx-sender (as-contract tx-sender)))
    
    ;; Reduce user's balance
    (set-balance tx-sender project-id (- user-balance amount))
    
    ;; Update project retired credits
    (map-set carbon-projects
        { project-id: project-id }
        (merge project-data {
            retired-credits: (+ (get retired-credits project-data) amount),
            available-credits: (- (get available-credits project-data) amount),
            last-updated: stacks-block-height
        })
    )
    
    ;; Record retirement
    (map-set retired-credits
        { retirement-id: retirement-id }
        {
            retiree: tx-sender,
            project-id: project-id,
            amount: amount,
            retirement-date: stacks-block-height,
            retirement-reason: retirement-reason,
            certificate-hash: certificate-hash
        }
    )
    
    ;; Update global statistics
    (var-set total-credits-retired (+ (var-get total-credits-retired) amount))
    (var-set next-retirement-id (+ retirement-id u1))
    (var-set platform-fee-balance (+ (var-get platform-fee-balance) RETIREMENT-FEE))
    
    ;; Record transaction
    (record-transaction tx-sender tx-sender project-id amount u0 "RETIREMENT")
    
    (ok retirement-id)
    )
)

;; ===================================================
;; READ-ONLY FUNCTIONS
;; ===================================================

;; Get project information
(define-read-only (get-project-info (project-id uint))
    (map-get? carbon-projects { project-id: project-id })
)

;; Get user's credit balance for a project
(define-read-only (get-credit-balance (user principal) (project-id uint))
    (get-balance user project-id)
)

;; Get trading order information
(define-read-only (get-order-info (order-id uint))
    (map-get? trading-orders { order-id: order-id })
)

;; Get retirement record
(define-read-only (get-retirement-info (retirement-id uint))
    (map-get? retired-credits { retirement-id: retirement-id })
)

;; Get verifier information
(define-read-only (get-verifier-info (verifier principal))
    (map-get? authorized-verifiers { verifier: verifier })
)

;; Get platform statistics
(define-read-only (get-platform-stats)
    {
        total-projects: (var-get next-project-id),
        total-credits-issued: (var-get total-credits-issued),
        total-credits-retired: (var-get total-credits-retired),
        active-orders: (var-get next-order-id),
        platform-fees: (var-get platform-fee-balance),
        trading-enabled: (var-get trading-enabled)
    }
)

;; Get transaction history
(define-read-only (get-transaction-info (tx-id uint))
    (map-get? transaction-history { tx-id: tx-id })
)

;; Calculate environmental impact
(define-read-only (calculate-co2-offset (retirement-id uint))
    (match (map-get? retired-credits { retirement-id: retirement-id })
        retirement-data (some (get amount retirement-data))
        none
    )
)

;; ===================================================
;; ADMIN FUNCTIONS
;; ===================================================

;; Toggle trading (emergency function)
(define-public (toggle-trading)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set trading-enabled (not (var-get trading-enabled)))
        (ok (var-get trading-enabled))
    )
)

;; Withdraw platform fees
(define-public (withdraw-fees (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get platform-fee-balance)) ERR-INSUFFICIENT-CREDITS)
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
        (var-set platform-fee-balance (- (var-get platform-fee-balance) amount))
        (ok amount)
    )
)