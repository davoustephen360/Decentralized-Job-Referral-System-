(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-referral (err u101))
(define-constant err-invalid-job (err u102))
(define-constant err-already-hired (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-invalid-vote (err u106))
(define-constant err-dispute-not-found (err u107))
(define-constant err-voting-ended (err u108))
(define-constant err-already-voted (err u109))
(define-constant err-invalid-application (err u110))
(define-constant err-already-applied (err u111))

(define-constant reward-amount u1000000)
(define-constant dispute-voting-period u1008)
(define-constant tier-1-threshold u3)
(define-constant tier-2-threshold u10)
(define-constant tier-3-threshold u25)
(define-constant bronze-multiplier u110)
(define-constant silver-multiplier u125)
(define-constant gold-multiplier u150)

(define-data-var next-referral-id uint u1)
(define-data-var next-job-id uint u1)
(define-data-var next-dispute-id uint u1)
(define-data-var next-application-id uint u1)
(define-data-var contract-balance uint u0)

(define-map referrals
  uint
  {
    referrer: principal,
    candidate: principal,
    job-id: uint,
    created-at: uint,
    status: (string-ascii 20)
  }
)

(define-map jobs
  uint
  {
    employer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    reward: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-map hires
  {job-id: uint, candidate: principal}
  {
    referral-id: uint,
    hire-block: uint,
    verified: bool,
    reward-paid: bool
  }
)

(define-map disputes
  uint
  {
    referral-id: uint,
    initiator: principal,
    reason: (string-ascii 200),
    created-at: uint,
    voting-end: uint,
    yes-votes: uint,
    no-votes: uint,
    resolved: bool
  }
)

(define-map dispute-votes
  {dispute-id: uint, voter: principal}
  bool
)

(define-map applications
  uint
  {
    applicant: principal,
    job-id: uint,
    cover-letter: (string-ascii 300),
    applied-at: uint,
    status: (string-ascii 20)
  }
)

(define-map user-referral-count principal uint)
(define-map user-hire-count principal uint)
(define-map user-earnings principal uint)
(define-map user-performance-tier principal uint)
(define-map user-successful-hires principal uint)
(define-map job-applications {job-id: uint, applicant: principal} uint)
(define-map tier-thresholds uint {min-hires: uint, bonus-multiplier: uint})

(define-public (create-job (title (string-ascii 100)) (description (string-ascii 500)) (reward uint))
  (let
    (
      (job-id (var-get next-job-id))
      (current-block burn-block-height)
    )
    (asserts! (> reward u0) err-insufficient-funds)
    (try! (stx-transfer? reward tx-sender (as-contract tx-sender)))
    (map-set jobs job-id
      {
        employer: tx-sender,
        title: title,
        description: description,
        reward: reward,
        created-at: current-block,
        is-active: true
      }
    )
    (var-set next-job-id (+ job-id u1))
    (var-set contract-balance (+ (var-get contract-balance) reward))
    (ok job-id)
  )
)

(define-public (apply-to-job (job-id uint) (cover-letter (string-ascii 300)))
  (let
    (
      (application-id (var-get next-application-id))
      (job-info (unwrap! (map-get? jobs job-id) err-invalid-job))
      (current-block burn-block-height)
    )
    (asserts! (get is-active job-info) err-invalid-job)
    (asserts! (not (is-eq tx-sender (get employer job-info))) err-unauthorized)
    (asserts! (is-none (map-get? job-applications {job-id: job-id, applicant: tx-sender})) err-already-applied)
    
    (map-set applications application-id
      {
        applicant: tx-sender,
        job-id: job-id,
        cover-letter: cover-letter,
        applied-at: current-block,
        status: "submitted"
      }
    )
    
    (map-set job-applications {job-id: job-id, applicant: tx-sender} application-id)
    (var-set next-application-id (+ application-id u1))
    (ok application-id)
  )
)

(define-public (update-application-status (application-id uint) (new-status (string-ascii 20)))
  (let
    (
      (application-info (unwrap! (map-get? applications application-id) err-invalid-application))
      (job-info (unwrap! (map-get? jobs (get job-id application-info)) err-invalid-job))
    )
    (asserts! (is-eq tx-sender (get employer job-info)) err-unauthorized)
    
    (map-set applications application-id
      (merge application-info {status: new-status})
    )
    (ok true)
  )
)

(define-public (create-referral (candidate principal) (job-id uint))
  (let
    (
      (referral-id (var-get next-referral-id))
      (job-info (unwrap! (map-get? jobs job-id) err-invalid-job))
      (current-block burn-block-height)
    )
    (asserts! (get is-active job-info) err-invalid-job)
    (asserts! (not (is-eq tx-sender candidate)) err-unauthorized)
    (map-set referrals referral-id
      {
        referrer: tx-sender,
        candidate: candidate,
        job-id: job-id,
        created-at: current-block,
        status: "pending"
      }
    )
    (var-set next-referral-id (+ referral-id u1))
    (map-set user-referral-count tx-sender 
      (+ (default-to u0 (map-get? user-referral-count tx-sender)) u1))
    (ok referral-id)
  )
)

(define-public (verify-hire (job-id uint) (candidate principal) (referral-id uint))
  (let
    (
      (job-info (unwrap! (map-get? jobs job-id) err-invalid-job))
      (referral-info (unwrap! (map-get? referrals referral-id) err-invalid-referral))
      (current-block burn-block-height)
    )
    (asserts! (is-eq tx-sender (get employer job-info)) err-unauthorized)
    (asserts! (is-eq candidate (get candidate referral-info)) err-invalid-referral)
    (asserts! (is-eq job-id (get job-id referral-info)) err-invalid-referral)
    (asserts! (is-none (map-get? hires {job-id: job-id, candidate: candidate})) err-already-hired)
    
    (map-set hires {job-id: job-id, candidate: candidate}
      {
        referral-id: referral-id,
        hire-block: current-block,
        verified: true,
        reward-paid: false
      }
    )
    
    (map-set referrals referral-id
      (merge referral-info {status: "hired"})
    )
    
    (map-set user-hire-count candidate
      (+ (default-to u0 (map-get? user-hire-count candidate)) u1))
    
    (map-set user-successful-hires (get referrer referral-info)
      (+ (default-to u0 (map-get? user-successful-hires (get referrer referral-info))) u1))
    
    (ok true)
  )
)

(define-public (process-reward (job-id uint) (candidate principal))
  (let
    (
      (hire-info (unwrap! (map-get? hires {job-id: job-id, candidate: candidate}) err-invalid-job))
      (referral-info (unwrap! (map-get? referrals (get referral-id hire-info)) err-invalid-referral))
      (job-info (unwrap! (map-get? jobs job-id) err-invalid-job))
      (referrer (get referrer referral-info))
    )
    (asserts! (get verified hire-info) err-unauthorized)
    (asserts! (not (get reward-paid hire-info)) err-already-hired)
    (asserts! (>= (var-get contract-balance) (get reward job-info)) err-insufficient-funds)
    
    (try! (as-contract (stx-transfer? (get reward job-info) tx-sender referrer)))
    
    (map-set hires {job-id: job-id, candidate: candidate}
      (merge hire-info {reward-paid: true})
    )
    
    (var-set contract-balance (- (var-get contract-balance) (get reward job-info)))
    
    (let
      (
        (bonus-multiplier (get-bonus-multiplier referrer))
        (bonus-reward (/ (* (get reward job-info) bonus-multiplier) u100))
      )
      (map-set user-earnings referrer
        (+ (default-to u0 (map-get? user-earnings referrer)) bonus-reward))
      
      (unwrap-panic (update-performance-tier referrer))
      
      (ok true)
    )
  )
)

(define-public (create-dispute (referral-id uint) (reason (string-ascii 200)))
  (let
    (
      (dispute-id (var-get next-dispute-id))
      (referral-info (unwrap! (map-get? referrals referral-id) err-invalid-referral))
      (current-block burn-block-height)
    )
    (asserts! (or 
      (is-eq tx-sender (get referrer referral-info))
      (is-eq tx-sender (get candidate referral-info))
    ) err-unauthorized)
    
    (map-set disputes dispute-id
      {
        referral-id: referral-id,
        initiator: tx-sender,
        reason: reason,
        created-at: current-block,
        voting-end: (+ current-block dispute-voting-period),
        yes-votes: u0,
        no-votes: u0,
        resolved: false
      }
    )
    
    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)
  )
)

(define-public (vote-on-dispute (dispute-id uint) (vote bool))
  (let
    (
      (dispute-info (unwrap! (map-get? disputes dispute-id) err-dispute-not-found))
      (current-block burn-block-height)
    )
    (asserts! (< current-block (get voting-end dispute-info)) err-voting-ended)
    (asserts! (is-none (map-get? dispute-votes {dispute-id: dispute-id, voter: tx-sender})) err-already-voted)
    
    (map-set dispute-votes {dispute-id: dispute-id, voter: tx-sender} vote)
    
    (if vote
      (map-set disputes dispute-id
        (merge dispute-info {yes-votes: (+ (get yes-votes dispute-info) u1)})
      )
      (map-set disputes dispute-id
        (merge dispute-info {no-votes: (+ (get no-votes dispute-info) u1)})
      )
    )
    
    (ok true)
  )
)

(define-public (resolve-dispute (dispute-id uint))
  (let
    (
      (dispute-info (unwrap! (map-get? disputes dispute-id) err-dispute-not-found))
      (current-block burn-block-height)
    )
    (asserts! (>= current-block (get voting-end dispute-info)) err-voting-ended)
    (asserts! (not (get resolved dispute-info)) err-invalid-vote)
    
    (map-set disputes dispute-id
      (merge dispute-info {resolved: true})
    )
    
    (ok (> (get yes-votes dispute-info) (get no-votes dispute-info)))
  )
)

(define-public (deactivate-job (job-id uint))
  (let
    (
      (job-info (unwrap! (map-get? jobs job-id) err-invalid-job))
    )
    (asserts! (is-eq tx-sender (get employer job-info)) err-unauthorized)
    (asserts! (get is-active job-info) err-invalid-job)
    
    (map-set jobs job-id
      (merge job-info {is-active: false})
    )
    
    (ok true)
  )
)

(define-public (emergency-withdraw)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (as-contract (stx-transfer? (stx-get-balance tx-sender) tx-sender contract-owner)))
    (var-set contract-balance u0)
    (ok true)
  )
)

(define-read-only (get-referral (referral-id uint))
  (map-get? referrals referral-id)
)

(define-read-only (get-job (job-id uint))
  (map-get? jobs job-id)
)

(define-read-only (get-hire (job-id uint) (candidate principal))
  (map-get? hires {job-id: job-id, candidate: candidate})
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id)
)

(define-read-only (get-user-stats (user principal))
  {
    referral-count: (default-to u0 (map-get? user-referral-count user)),
    hire-count: (default-to u0 (map-get? user-hire-count user)),
    total-earnings: (default-to u0 (map-get? user-earnings user))
  }
)

(define-read-only (get-contract-balance)
  (var-get contract-balance)
)

(define-read-only (has-voted-on-dispute (dispute-id uint) (voter principal))
  (is-some (map-get? dispute-votes {dispute-id: dispute-id, voter: voter}))
)

(define-read-only (get-application (application-id uint))
  (map-get? applications application-id)
)

(define-read-only (get-user-application-for-job (job-id uint) (applicant principal))
  (match (map-get? job-applications {job-id: job-id, applicant: applicant})
    application-id (map-get? applications application-id)
    none
  )
)

(define-private (get-bonus-multiplier (user principal))
  (let
    (
      (successful-hires (default-to u0 (map-get? user-successful-hires user)))
    )
    (if (>= successful-hires tier-3-threshold)
      gold-multiplier
      (if (>= successful-hires tier-2-threshold)
        silver-multiplier
        (if (>= successful-hires tier-1-threshold)
          bronze-multiplier
          u100
        )
      )
    )
  )
)

(define-private (update-performance-tier (user principal))
  (let
    (
      (successful-hires (default-to u0 (map-get? user-successful-hires user)))
      (new-tier 
        (if (>= successful-hires tier-3-threshold)
          u3
          (if (>= successful-hires tier-2-threshold)
            u2
            (if (>= successful-hires tier-1-threshold)
              u1
              u0
            )
          )
        )
      )
    )
    (map-set user-performance-tier user new-tier)
    (ok true)
  )
)

(define-read-only (get-user-performance (user principal))
  {
    performance-tier: (default-to u0 (map-get? user-performance-tier user)),
    successful-hires: (default-to u0 (map-get? user-successful-hires user)),
    current-bonus-multiplier: (get-bonus-multiplier user)
  }
)

(define-read-only (get-tier-info (tier uint))
  (if (is-eq tier u1)
    {tier-name: "Bronze", min-hires: tier-1-threshold, bonus-multiplier: bronze-multiplier}
    (if (is-eq tier u2)
      {tier-name: "Silver", min-hires: tier-2-threshold, bonus-multiplier: silver-multiplier}
      (if (is-eq tier u3)
        {tier-name: "Gold", min-hires: tier-3-threshold, bonus-multiplier: gold-multiplier}
        {tier-name: "Starter", min-hires: u0, bonus-multiplier: u100}
      )
    )
  )
)

(define-read-only (get-next-ids)
  {
    next-referral-id: (var-get next-referral-id),
    next-job-id: (var-get next-job-id),
    next-dispute-id: (var-get next-dispute-id),
    next-application-id: (var-get next-application-id)
  }
)
