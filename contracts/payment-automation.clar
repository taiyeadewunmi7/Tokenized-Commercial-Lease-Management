;; Payment Automation Contract
;; Handles recurring rent transactions

(define-data-var contract-owner principal tx-sender)

;; Payment record structure
(define-map payment-records
  { payment-id: uint }
  {
    lease-id: uint,
    amount: uint,
    due-date: uint,
    paid-date: (optional uint),
    paid: bool,
    payer: (optional principal),
    payment-method: (string-ascii 20),
    late-fee: uint
  }
)

;; Lease information (simplified)
(define-map lease-info
  { lease-id: uint }
  {
    landlord: principal,
    tenant: principal,
    monthly-rent: uint,
    active: bool
  }
)

;; Payment schedule structure
(define-map payment-schedules
  { lease-id: uint }
  {
    next-payment-date: uint,
    payment-frequency: uint, ;; in blocks
    monthly-rent: uint,
    late-fee-percent: uint,
    grace-period: uint       ;; in blocks
  }
)

;; Counter variable
(define-data-var next-payment-id uint u1)

;; Register lease information (simplified)
(define-public (register-lease
    (lease-id uint)
    (landlord principal)
    (tenant principal)
    (monthly-rent uint))
  (if (map-insert lease-info
      { lease-id: lease-id }
      {
        landlord: landlord,
        tenant: tenant,
        monthly-rent: monthly-rent,
        active: true
      })
    (ok true)
    (err u1)))

;; Create a payment schedule for a lease
(define-public (create-payment-schedule
    (lease-id uint)
    (start-date uint)
    (payment-frequency uint)
    (monthly-rent uint)
    (late-fee-percent uint)
    (grace-period uint))
  (match (map-get? lease-info { lease-id: lease-id })
    lease-data
      (if (is-eq tx-sender (get landlord lease-data))
        (if (map-insert payment-schedules
            { lease-id: lease-id }
            {
              next-payment-date: start-date,
              payment-frequency: payment-frequency,
              monthly-rent: monthly-rent,
              late-fee-percent: late-fee-percent,
              grace-period: grace-period
            })
          (ok true)
          (err u1))
        (err u2))
    (err u3)))

;; Generate the next payment record for a lease
(define-public (generate-payment
    (lease-id uint))
  (match (map-get? payment-schedules { lease-id: lease-id })
    schedule
      (let
        ((payment-id (var-get next-payment-id))
         (next-date (get next-payment-date schedule)))
        (match (map-get? lease-info { lease-id: lease-id })
          lease-data
            (if (and
                  (is-eq tx-sender (get landlord lease-data))
                  (map-insert payment-records
                    { payment-id: payment-id }
                    {
                      lease-id: lease-id,
                      amount: (get monthly-rent schedule),
                      due-date: next-date,
                      paid-date: none,
                      paid: false,
                      payer: none,
                      payment-method: "",
                      late-fee: u0
                    }))
              (begin
                (var-set next-payment-id (+ payment-id u1))
                (map-set payment-schedules
                  { lease-id: lease-id }
                  (merge schedule {
                    next-payment-date: (+ next-date (get payment-frequency schedule))
                  }))
                (ok payment-id))
              (err u4))
          (err u3)))
    (err u5)))

;; Make a payment
(define-public (make-payment
    (payment-id uint)
    (payment-method (string-ascii 20)))
  (match (map-get? payment-records { payment-id: payment-id })
    payment-data
      (match (map-get? lease-info { lease-id: (get lease-id payment-data) })
        lease-data
          (if (is-eq tx-sender (get tenant lease-data))
            (let
              ((current-block block-height)
               (due-date (get due-date payment-data))
               (late-fee-amount u0))
              (if (map-set payment-records
                  { payment-id: payment-id }
                  (merge payment-data {
                    paid-date: (some current-block),
                    paid: true,
                    payer: (some tx-sender),
                    payment-method: payment-method,
                    late-fee: late-fee-amount
                  }))
                (ok true)
                (err u6)))
            (err u2))
        (err u3))
    (err u7)))

;; Calculate late fee for a payment
(define-read-only (calculate-late-fee
    (payment-id uint))
  (match (map-get? payment-records { payment-id: payment-id })
    payment-data
      (if (get paid payment-data)
        u0
        (match (map-get? payment-schedules { lease-id: (get lease-id payment-data) })
          schedule
            (let
              ((due-date (get due-date payment-data))
               (grace-period (get grace-period schedule))
               (current-block block-height))
              (if (> current-block (+ due-date grace-period))
                (/ (* (get amount payment-data) (get late-fee-percent schedule)) u100)
                u0))
          u0))
    u0))

;; Get payment record
(define-read-only (get-payment (payment-id uint))
  (map-get? payment-records { payment-id: payment-id })
)

;; Get payment schedule
(define-read-only (get-payment-schedule (lease-id uint))
  (map-get? payment-schedules { lease-id: lease-id })
)

