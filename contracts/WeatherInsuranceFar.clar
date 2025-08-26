;; WeatherInsurance Farm Contract
;; Parametric weather insurance for farmers with automatic payouts and risk assessment

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-policy-not-found (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-policy-expired (err u104))

;; Data Variables
(define-data-var next-policy-id uint u1)
(define-data-var contract-balance uint u0)

;; Data Maps
(define-map insurance-policies
  uint 
  {
    farmer: principal,
    premium-paid: uint,
    coverage-amount: uint,
    rainfall-threshold: uint,
    policy-duration: uint,
    policy-start: uint,
    active: bool
  })

;; Function 1: Purchase Insurance Policy
;; Allows farmers to buy weather insurance by depositing premium
(define-public (purchase-policy (coverage-amount uint) (rainfall-threshold uint) (duration-blocks uint))
  (let 
    (
      (policy-id (var-get next-policy-id))
      (premium (/ coverage-amount u5)) ;; Premium is 20% of coverage amount
    )
    (begin
      ;; Validate inputs
      (asserts! (> coverage-amount u0) err-invalid-amount)
      (asserts! (> rainfall-threshold u0) err-invalid-amount)
      (asserts! (> duration-blocks u0) err-invalid-amount)
      
      ;; Transfer premium from farmer to contract
      (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
      
      ;; Create insurance policy
      (map-set insurance-policies policy-id
  {
    farmer: tx-sender,
    premium-paid: premium,
    coverage-amount: coverage-amount,
    rainfall-threshold: rainfall-threshold,
    policy-duration: duration-blocks,
    policy-start:stacks-block-height,
    active: true
  })

      
      ;; Update contract balance and policy counter
      (var-set contract-balance (+ (var-get contract-balance) premium))
      (var-set next-policy-id (+ policy-id u1))
      
      (print {event: "policy-purchased", policy-id: policy-id, farmer: tx-sender, coverage: coverage-amount})
      (ok policy-id))))

;; Function 2: Execute Payout
;; Processes automatic payout based on weather data
(define-public (execute-payout (policy-id uint) (recorded-rainfall uint))
  (let 
    (
      (policy (unwrap! (map-get? insurance-policies policy-id) err-policy-not-found))
      (farmer (get farmer policy))
      (coverage (get coverage-amount policy))
      (threshold (get rainfall-threshold policy))
      (policy-start (get policy-start policy))
      (duration (get policy-duration policy))
      (is-active (get active policy))
    )
    (begin
      ;; Validate payout conditions
      (asserts! is-active err-policy-expired)
      (asserts! (<= stacks-block-height (+ policy-start duration)) err-policy-expired)
      (asserts! (< recorded-rainfall threshold) err-invalid-amount)
      (asserts! (>= (var-get contract-balance) coverage) err-insufficient-funds)
      
      ;; Process payout to farmer
      (try! (as-contract (stx-transfer? coverage tx-sender farmer)))
      
      ;; Deactivate policy after payout
      (map-set insurance-policies policy-id
        (merge policy {active: false}))
      
      ;; Update contract balance
      (var-set contract-balance (- (var-get contract-balance) coverage))
      
      (print {event: "payout-executed", policy-id: policy-id, farmer: farmer, amount: coverage, rainfall: recorded-rainfall})
      (ok coverage))))

;; Read-only functions
(define-read-only (get-policy-details (policy-id uint))
  (ok (map-get? insurance-policies policy-id)))

(define-read-only (get-contract-balance)
  (ok (var-get contract-balance)))