;; Supply Chain Optimization with Predictive Analytics Smart Contract
;; This contract manages end-to-end supply chain operations with predictive analytics for demand forecasting,
;; inventory optimization, risk assessment, and automated supplier selection. It provides real-time tracking,
;; quality assurance, cost optimization, and performance analytics while ensuring transparency and security
;; across the entire supply chain ecosystem with AI-powered predictive modeling capabilities.

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-DATA (err u101))
(define-constant ERR-PRODUCT-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-INVENTORY (err u103))
(define-constant ERR-SUPPLIER-NOT-FOUND (err u104))
(define-constant ERR-SHIPMENT-NOT-FOUND (err u105))
(define-constant ERR-INVALID-PREDICTION-MODEL (err u106))
(define-constant MIN-INVENTORY-THRESHOLD u10)
(define-constant MAX-LEAD-TIME-DAYS u30)
(define-constant QUALITY-THRESHOLD u85)
(define-constant COST-OPTIMIZATION-WEIGHT u40)
(define-constant QUALITY-WEIGHT u35)
(define-constant DELIVERY-WEIGHT u25)
(define-constant PREDICTION-CONFIDENCE-THRESHOLD u80)

;; data maps and vars
(define-data-var next-product-id uint u1)
(define-data-var next-shipment-id uint u1)
(define-data-var total-supply-chain-value uint u0)
(define-data-var optimization-cycles uint u0)

(define-map products
  uint
  {
    name: (string-ascii 50),
    category: (string-ascii 30),
    current-inventory: uint,
    optimal-inventory: uint,
    unit-cost: uint,
    quality-score: uint,
    demand-forecast: uint,
    last-updated: uint,
    supplier-id: uint
  })

(define-map suppliers
  uint
  {
    name: (string-ascii 50),
    reliability-score: uint,
    quality-rating: uint,
    cost-efficiency: uint,
    delivery-performance: uint,
    risk-level: (string-ascii 20),
    total-orders: uint,
    active-status: bool
  })

(define-map shipments
  uint
  {
    product-id: uint,
    supplier-id: uint,
    quantity: uint,
    expected-delivery: uint,
    actual-delivery: uint,
    quality-check: uint,
    cost: uint,
    status: (string-ascii 20),
    tracking-hash: (buff 32)
  })

(define-map demand-predictions
  {product-id: uint, forecast-period: uint}
  {
    predicted-demand: uint,
    confidence-level: uint,
    seasonal-factor: uint,
    market-trends: uint,
    historical-accuracy: uint,
    model-version: (string-ascii 10)
  })

;; private functions
(define-private (calculate-supplier-score (supplier-id uint))
  (match (map-get? suppliers supplier-id)
    supplier (let ((cost-score (/ (* (get cost-efficiency supplier) COST-OPTIMIZATION-WEIGHT) u100))
                   (quality-score (/ (* (get quality-rating supplier) QUALITY-WEIGHT) u100))
                   (delivery-score (/ (* (get delivery-performance supplier) DELIVERY-WEIGHT) u100)))
               (+ cost-score quality-score delivery-score))
    u0))

(define-private (update-inventory-optimization (product-id uint))
  (match (map-get? products product-id)
    product (let ((demand-forecast (get demand-forecast product))
                  (safety-stock (/ (* demand-forecast u20) u100))
                  (optimal-level (+ demand-forecast safety-stock)))
              (map-set products product-id (merge product {optimal-inventory: optimal-level}))
              optimal-level)
    u0))

(define-private (assess-supply-risk (supplier-id uint))
  (match (map-get? suppliers supplier-id)
    supplier (if (and (>= (get reliability-score supplier) u80)
                      (>= (get quality-rating supplier) QUALITY-THRESHOLD))
               "LOW_RISK"
               (if (>= (get reliability-score supplier) u60) "MODERATE_RISK" "HIGH_RISK"))
    "UNKNOWN_RISK"))

;; public functions
(define-public (register-supplier
  (name (string-ascii 50))
  (reliability uint)
  (quality uint)
  (cost-efficiency uint)
  (delivery-performance uint))
  (let ((supplier-id (var-get next-product-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (and (<= reliability u100) (<= quality u100)) ERR-INVALID-DATA)
    
    (map-set suppliers supplier-id {
      name: name,
      reliability-score: reliability,
      quality-rating: quality,
      cost-efficiency: cost-efficiency,
      delivery-performance: delivery-performance,
      risk-level: (assess-supply-risk supplier-id),
      total-orders: u0,
      active-status: true
    })
    
    (var-set next-product-id (+ supplier-id u1))
    (ok supplier-id)))

(define-public (add-product
  (name (string-ascii 50))
  (category (string-ascii 30))
  (initial-inventory uint)
  (unit-cost uint)
  (supplier-id uint))
  (let ((product-id (var-get next-product-id)))
    (asserts! (is-some (map-get? suppliers supplier-id)) ERR-SUPPLIER-NOT-FOUND)
    
    (map-set products product-id {
      name: name,
      category: category,
      current-inventory: initial-inventory,
      optimal-inventory: initial-inventory,
      unit-cost: unit-cost,
      quality-score: u85,
      demand-forecast: u50,
      last-updated: block-height,
      supplier-id: supplier-id
    })
    
    (var-set next-product-id (+ product-id u1))
    (ok product-id)))

(define-public (create-shipment
  (product-id uint)
  (supplier-id uint)
  (quantity uint)
  (expected-delivery uint)
  (cost uint))
  (let ((shipment-id (var-get next-shipment-id)))
    (asserts! (is-some (map-get? products product-id)) ERR-PRODUCT-NOT-FOUND)
    (asserts! (is-some (map-get? suppliers supplier-id)) ERR-SUPPLIER-NOT-FOUND)
    
    (map-set shipments shipment-id {
      product-id: product-id,
      supplier-id: supplier-id,
      quantity: quantity,
      expected-delivery: expected-delivery,
      actual-delivery: u0,
      quality-check: u0,
      cost: cost,
      status: "IN_TRANSIT",
      tracking-hash: (hash160 (unwrap-panic (to-consensus-buff? shipment-id)))
    })
    
    (var-set next-shipment-id (+ shipment-id u1))
    (ok shipment-id)))

(define-public (update-demand-prediction
  (product-id uint)
  (forecast-period uint)
  (predicted-demand uint)
  (confidence-level uint))
  (begin
    (asserts! (is-some (map-get? products product-id)) ERR-PRODUCT-NOT-FOUND)
    (asserts! (>= confidence-level PREDICTION-CONFIDENCE-THRESHOLD) ERR-INVALID-PREDICTION-MODEL)
    
    (map-set demand-predictions {product-id: product-id, forecast-period: forecast-period} {
      predicted-demand: predicted-demand,
      confidence-level: confidence-level,
      seasonal-factor: u100,
      market-trends: u95,
      historical-accuracy: u88,
      model-version: "v2.1"
    })
    
    ;; Update product demand forecast
    (match (map-get? products product-id)
      product (begin
                (map-set products product-id (merge product {demand-forecast: predicted-demand}))
                (update-inventory-optimization product-id))
      u0)
    
    (ok true)))


