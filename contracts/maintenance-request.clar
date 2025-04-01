;; Maintenance Request Contract
;; Tracks repair needs and resolutions

(define-data-var contract-owner principal tx-sender)

;; Maintenance request structure
(define-map maintenance-requests
  { request-id: uint }
  {
    lease-id: uint,
    property-id: uint,
    requester: principal,
    description: (string-ascii 1024),
    priority: (string-ascii 10),     ;; "low", "medium", "high", "emergency"
    status: (string-ascii 20),       ;; "pending", "assigned", "in-progress", "completed", "cancelled"
    created-at: uint,
    assigned-to: (optional principal),
    completed-at: (optional uint),
    resolution-notes: (string-ascii 1024)
  }
)

;; Lease information (simplified)
(define-map lease-info
  { lease-id: uint }
  {
    property-id: uint,
    landlord: principal,
    tenant: principal
  }
)

;; Counter variable
(define-data-var next-request-id uint u1)

;; Register lease information (simplified)
(define-public (register-lease
    (lease-id uint)
    (property-id uint)
    (landlord principal)
    (tenant principal))
  (if (map-insert lease-info
      { lease-id: lease-id }
      {
        property-id: property-id,
        landlord: landlord,
        tenant: tenant
      })
    (ok true)
    (err u1)))

;; Create a maintenance request
(define-public (create-request
    (lease-id uint)
    (description (string-ascii 1024))
    (priority (string-ascii 10)))
  (match (map-get? lease-info { lease-id: lease-id })
    lease-data
      (let
        ((request-id (var-get next-request-id)))
        (if (or
              (is-eq tx-sender (get tenant lease-data))
              (is-eq tx-sender (get landlord lease-data)))
          (if (map-insert maintenance-requests
              { request-id: request-id }
              {
                lease-id: lease-id,
                property-id: (get property-id lease-data),
                requester: tx-sender,
                description: description,
                priority: priority,
                status: "pending",
                created-at: block-height,
                assigned-to: none,
                completed-at: none,
                resolution-notes: ""
              })
            (begin
              (var-set next-request-id (+ request-id u1))
              (ok request-id))
            (err u1))
          (err u2)))
    (err u3)))

;; Assign a maintenance request
(define-public (assign-request
    (request-id uint)
    (assignee principal))
  (match (map-get? maintenance-requests { request-id: request-id })
    request-data
      (match (map-get? lease-info { lease-id: (get lease-id request-data) })
        lease-data
          (if (is-eq tx-sender (get landlord lease-data))
            (if (map-set maintenance-requests
                { request-id: request-id }
                (merge request-data {
                  status: "assigned",
                  assigned-to: (some assignee)
                }))
              (ok true)
              (err u4))
            (err u2))
        (err u3))
    (err u5)))

;; Update maintenance request status
(define-public (update-request-status
    (request-id uint)
    (new-status (string-ascii 20)))
  (match (map-get? maintenance-requests { request-id: request-id })
    request-data
      (match (map-get? lease-info { lease-id: (get lease-id request-data) })
        lease-data
          (if (or
                (is-eq tx-sender (get landlord lease-data))
                (is-some (get assigned-to request-data))
                (is-eq tx-sender (default-to tx-sender (get assigned-to request-data))))
            (if (map-set maintenance-requests
                { request-id: request-id }
                (merge request-data {
                  status: new-status,
                  completed-at: (if (is-eq new-status "completed") (some block-height) (get completed-at request-data))
                }))
              (ok true)
              (err u4))
            (err u2))
        (err u3))
    (err u5)))

;; Add resolution notes
(define-public (add-resolution-notes
    (request-id uint)
    (notes (string-ascii 1024)))
  (match (map-get? maintenance-requests { request-id: request-id })
    request-data
      (match (map-get? lease-info { lease-id: (get lease-id request-data) })
        lease-data
          (if (or
                (is-eq tx-sender (get landlord lease-data))
                (is-some (get assigned-to request-data))
                (is-eq tx-sender (default-to tx-sender (get assigned-to request-data))))
            (if (map-set maintenance-requests
                { request-id: request-id }
                (merge request-data {
                  resolution-notes: notes
                }))
              (ok true)
              (err u4))
            (err u2))
        (err u3))
    (err u5)))

;; Get maintenance request
(define-read-only (get-request (request-id uint))
  (map-get? maintenance-requests { request-id: request-id })
)

;; Get all maintenance requests for a property
(define-read-only (get-property-requests (property-id uint))
  ;; In a real implementation, this would need to be paginated
  ;; or implemented using an NFT standard with ownership tracking
  property-id
)

;; Cancel request (can be done by requester or landlord)
(define-public (cancel-request
    (request-id uint))
  (match (map-get? maintenance-requests { request-id: request-id })
    request-data
      (match (map-get? lease-info { lease-id: (get lease-id request-data) })
        lease-data
          (if (or
                (is-eq tx-sender (get landlord lease-data))
                (is-eq tx-sender (get requester request-data)))
            (if (map-set maintenance-requests
                { request-id: request-id }
                (merge request-data {
                  status: "cancelled"
                }))
              (ok true)
              (err u4))
            (err u2))
        (err u3))
    (err u5)))

