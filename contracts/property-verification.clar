;; Property Verification Contract
;; This contract validates ownership and condition of properties

(define-data-var contract-owner principal tx-sender)

;; Property structure
(define-map properties
  { property-id: uint }
  {
    owner: principal,
    address: (string-ascii 256),
    verified: bool,
    last-inspection-date: uint,
    condition-score: uint,
    property-details: (string-ascii 1024)
  }
)

;; Property verification events
(define-data-var next-property-id uint u1)

;; Read-only function to get the next property ID
(define-read-only (get-next-property-id)
  (var-get next-property-id)
)

;; Register a new property
(define-public (register-property
    (address (string-ascii 256))
    (property-details (string-ascii 1024)))
  (let
    ((property-id (var-get next-property-id)))
    (if (map-insert properties
        { property-id: property-id }
        {
          owner: tx-sender,
          address: address,
          verified: false,
          last-inspection-date: u0,
          condition-score: u0,
          property-details: property-details
        })
      (begin
        (var-set next-property-id (+ property-id u1))
        (ok property-id))
      (err u1))))

;; Verify a property (only contract owner can verify)
(define-public (verify-property
    (property-id uint)
    (condition-score uint))
  (let
    ((owner (var-get contract-owner)))
    (if (is-eq tx-sender owner)
      (match (map-get? properties { property-id: property-id })
        property-data
          (if (map-set properties
              { property-id: property-id }
              (merge property-data {
                verified: true,
                last-inspection-date: block-height,
                condition-score: condition-score
              }))
            (ok true)
            (err u3))
        (err u2))
      (err u4))))

;; Get property details
(define-read-only (get-property (property-id uint))
  (map-get? properties { property-id: property-id })
)

;; Update property details (only by owner)
(define-public (update-property-details
    (property-id uint)
    (new-details (string-ascii 1024)))
  (match (map-get? properties { property-id: property-id })
    property-data
      (if (is-eq tx-sender (get owner property-data))
        (if (map-set properties
            { property-id: property-id }
            (merge property-data {
              property-details: new-details,
              verified: false
            }))
          (ok true)
          (err u5))
        (err u6))
    (err u2)))

