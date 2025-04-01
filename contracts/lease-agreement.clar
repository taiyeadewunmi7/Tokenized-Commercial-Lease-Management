;; Lease Agreement Contract
;; Manages terms between landlords and tenants

(define-data-var contract-owner principal tx-sender)

;; Lease structure
(define-map leases
  { lease-id: uint }
  {
    property-id: uint,
    landlord: principal,
    tenant: principal,
    start-date: uint,
    end-date: uint,
    monthly-rent: uint,
    security-deposit: uint,
    active: bool,
    terms: (string-ascii 1024)
  }
)

;; Property ownership tracking (simplified approach)
(define-map property-owners
  { property-id: uint }
  { owner: principal }
)

;; Lease application structure
(define-map lease-applications
  { application-id: uint }
  {
    property-id: uint,
    applicant: principal,
    proposed-start-date: uint,
    proposed-duration: uint,
    status: (string-ascii 20)  ;; "pending", "approved", "rejected"
  }
)

;; Counter variables
(define-data-var next-lease-id uint u1)
(define-data-var next-application-id uint u1)

;; Register property ownership (simplified)
(define-public (register-property-ownership
    (property-id uint))
  (if (map-insert property-owners
      { property-id: property-id }
      { owner: tx-sender })
    (ok true)
    (err u1)))

;; Create a new lease
(define-public (create-lease
    (property-id uint)
    (tenant principal)
    (start-date uint)
    (end-date uint)
    (monthly-rent uint)
    (security-deposit uint)
    (terms (string-ascii 1024)))
  (let
    ((lease-id (var-get next-lease-id)))
    ;; Check if caller is property owner
    (match (map-get? property-owners { property-id: property-id })
      property-owner
        (if (is-eq tx-sender (get owner property-owner))
          (if (map-insert leases
              { lease-id: lease-id }
              {
                property-id: property-id,
                landlord: tx-sender,
                tenant: tenant,
                start-date: start-date,
                end-date: end-date,
                monthly-rent: monthly-rent,
                security-deposit: security-deposit,
                active: true,
                terms: terms
              })
            (begin
              (var-set next-lease-id (+ lease-id u1))
              (ok lease-id))
            (err u1))
          (err u2))
      (err u3))))

;; Apply for a lease
(define-public (apply-for-lease
    (property-id uint)
    (proposed-start-date uint)
    (proposed-duration uint))
  (let
    ((application-id (var-get next-application-id)))
    (if (map-insert lease-applications
        { application-id: application-id }
        {
          property-id: property-id,
          applicant: tx-sender,
          proposed-start-date: proposed-start-date,
          proposed-duration: proposed-duration,
          status: "pending"
        })
      (begin
        (var-set next-application-id (+ application-id u1))
        (ok application-id))
      (err u1))))

;; Approve or reject a lease application (only by property owner)
(define-public (respond-to-application
    (application-id uint)
    (approved bool))
  (match (map-get? lease-applications { application-id: application-id })
    application-data
      (match (map-get? property-owners { property-id: (get property-id application-data) })
        property-owner
          (if (is-eq tx-sender (get owner property-owner))
            (if (map-set lease-applications
                { application-id: application-id }
                (merge application-data {
                  status: (if approved "approved" "rejected")
                }))
              (ok true)
              (err u4))
            (err u2))
        (err u3))
    (err u5)))

;; Terminate a lease (can be called by landlord)
(define-public (terminate-lease
    (lease-id uint))
  (match (map-get? leases { lease-id: lease-id })
    lease-data
      (if (is-eq tx-sender (get landlord lease-data))
        (if (map-set leases
            { lease-id: lease-id }
            (merge lease-data {
              active: false
            }))
          (ok true)
          (err u6))
        (err u2))
    (err u7)))

;; Get lease details
(define-read-only (get-lease (lease-id uint))
  (map-get? leases { lease-id: lease-id })
)

;; Get application details
(define-read-only (get-application (application-id uint))
  (map-get? lease-applications { application-id: application-id })
)

