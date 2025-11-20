;; Decentralized Job Referral System with Reputation
;; A comprehensive platform for job referrals, hiring, and reputation management

;; Error constants
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
(define-constant err-invalid-rating (err u112))
(define-constant err-self-rating (err u113))
(define-constant err-no-interaction (err u114))
(define-constant err-already-rated (err u115))
(define-constant err-insufficient-reputation (err u116))

;; Contract owner
(define-constant contract-owner tx-sender)

;; System constants
(define-constant reward-amount u1000000)
(define-constant dispute-voting-period u1008)
(define-constant tier-1-threshold u3)
(define-constant tier-2-threshold u10)
(define-constant tier-3-threshold u25)
(define-constant bronze-multiplier u110)
(define-constant silver-multiplier u125)
(define-constant gold-multiplier u150)

;; Job Referral Rewards System Constants
(define-constant base-referral-reward u50000)
(define-constant performance-tier-bronze u5)
(define-constant performance-tier-silver u15)
(define-constant performance-tier-gold u30)
(define-constant success-rate-threshold-bronze u60)
(define-constant success-rate-threshold-silver u75)
(define-constant success-rate-threshold-gold u90)
(define-constant reward-multiplier-bronze u120)
(define-constant reward-multiplier-silver u150)
(define-constant reward-multiplier-gold u200)
(define-constant bonus-streak-threshold u5)
(define-constant streak-bonus-multiplier u110)

;; Reputation system constants
(define-constant min-rating u1)
(define-constant max-rating u5)
(define-constant successful-referral-points u10)
(define-constant successful-hire-points u15)
(define-constant dispute-penalty-points u20)
(define-constant quality-rating-bonus u5)
(define-constant min-reputation-for-premium u100)

;; Data variables
(define-data-var next-referral-id uint u1)
(define-data-var next-job-id uint u1)
(define-data-var next-dispute-id uint u1)
(define-data-var next-application-id uint u1)
(define-data-var next-rating-id uint u1)
(define-data-var contract-balance uint u0)

;; Core system maps
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
    is-active: bool,
    min-reputation: uint
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

;; User tracking maps
(define-map user-referral-count principal uint)
(define-map user-hire-count principal uint)
(define-map user-earnings principal uint)
(define-map user-performance-tier principal uint)
(define-map user-successful-hires principal uint)
(define-map job-applications {job-id: uint, applicant: principal} uint)

;; Job Referral Rewards System Maps
(define-map referrer-performance
  principal
  {
    total-referrals: uint,
    successful-hires: uint,
    success-rate: uint,
    current-tier: uint,
    total-rewards-earned: uint,
    current-streak: uint,
    longest-streak: uint,
    last-successful-hire: uint
  }
)

(define-map referral-rewards
  uint
  {
    referral-id: uint,
    base-reward: uint,
    tier-multiplier: uint,
    streak-bonus: uint,
    total-reward: uint,
    distributed: bool,
    distribution-block: uint
  }
)

;; Reputation system maps
(define-map user-reputation principal uint)
(define-map user-ratings 
  uint
  {
    rater: principal,
    rated-user: principal,
    rating: uint,
    interaction-type: (string-ascii 20),
    interaction-id: uint,
    comment: (string-ascii 200),
    created-at: uint
  }
)
(define-map interaction-ratings {interaction-type: (string-ascii 20), interaction-id: uint, rater: principal} uint)
(define-map user-rating-summary 
  principal 
  {
    total-ratings: uint,
    average-rating: uint,
    five-star: uint,
    four-star: uint,
    three-star: uint,
    two-star: uint,
    one-star: uint,
    reputation-points: uint
  }
)

;; Job creation with reputation requirements
(define-public (create-job (title (string-ascii 100)) (description (string-ascii 500)) (reward uint) (min-reputation uint))
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
        is-active: true,
        min-reputation: min-reputation
      }
    )
    (var-set next-job-id (+ job-id u1))
    (var-set contract-balance (+ (var-get contract-balance) reward))
    (ok job-id)
  )
)

;; Enhanced job application with reputation check
(define-public (apply-to-job (job-id uint) (cover-letter (string-ascii 300)))
  (let
    (
      (application-id (var-get next-application-id))
      (job-info (unwrap! (map-get? jobs job-id) err-invalid-job))
      (current-block burn-block-height)
      (user-rep (default-to u0 (map-get? user-reputation tx-sender)))
    )
    (asserts! (get is-active job-info) err-invalid-job)
    (asserts! (not (is-eq tx-sender (get employer job-info))) err-unauthorized)
    (asserts! (is-none (map-get? job-applications {job-id: job-id, applicant: tx-sender})) err-already-applied)
    (asserts! (>= user-rep (get min-reputation job-info)) err-insufficient-reputation)
    
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

;; Create referral with reputation boost
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
    
    ;; Award reputation points for creating referral
    (unwrap-panic (update-reputation tx-sender successful-referral-points))
    (ok referral-id)
  )
)

(define-public (update-application-status (application-id uint) (new-status (string-ascii 20)))
  (let
    (
      (application-info (unwrap! (map-get? applications application-id) err-invalid-application))
      (job-info (unwrap! (map-get? jobs (get job-id application-info)) err-invalid-job))
      (current-status (get status application-info))
    )
    (asserts! (is-eq tx-sender (get employer job-info)) err-unauthorized)
    (asserts! (is-eq current-status "submitted") err-invalid-application)
    (asserts! (or (is-eq new-status "accepted") (is-eq new-status "rejected")) err-invalid-application)
    (map-set applications application-id (merge application-info {status: new-status}))
    (ok true)
  )
)

;; Enhanced hire verification with reputation updates
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
    
    ;; Award reputation points for successful hire
    (unwrap-panic (update-reputation candidate successful-hire-points))
    (unwrap-panic (update-reputation (get referrer referral-info) successful-hire-points))
    
    (ok true)
  )
)

;; JOB REFERRAL REWARDS SYSTEM FUNCTIONS

;; Calculate referral reward based on performance tier and success rate
(define-private (calculate-referral-reward (referrer principal) (job-reward uint))
  (let
    (
      (performance (default-to 
        {total-referrals: u0, successful-hires: u0, success-rate: u0, current-tier: u0, total-rewards-earned: u0, current-streak: u0, longest-streak: u0, last-successful-hire: u0}
        (map-get? referrer-performance referrer)))
      (base-reward (min base-referral-reward (/ job-reward u10)))
      (tier-multiplier (get-tier-multiplier (get current-tier performance)))
      (streak-bonus (if (>= (get current-streak performance) bonus-streak-threshold) streak-bonus-multiplier u100))
    )
    {
      base-reward: base-reward,
      tier-multiplier: tier-multiplier,
      streak-bonus: streak-bonus,
      total-reward: (/ (* (* base-reward tier-multiplier) streak-bonus) u10000)
    }
  )
)

;; Get performance tier multiplier
(define-private (get-tier-multiplier (tier uint))
  (if (is-eq tier u3)
    reward-multiplier-gold
    (if (is-eq tier u2)
      reward-multiplier-silver
      (if (is-eq tier u1)
        reward-multiplier-bronze
        u100
      )
    )
  )
)

;; Update referrer performance metrics
(define-private (update-referrer-performance (referrer principal) (successful bool))
  (let
    (
      (current-performance (default-to 
        {total-referrals: u0, successful-hires: u0, success-rate: u0, current-tier: u0, total-rewards-earned: u0, current-streak: u0, longest-streak: u0, last-successful-hire: u0}
        (map-get? referrer-performance referrer)))
      (new-total (+ (get total-referrals current-performance) u1))
      (new-successful (if successful (+ (get successful-hires current-performance) u1) (get successful-hires current-performance)))
      (new-success-rate (if (> new-total u0) (/ (* new-successful u100) new-total) u0))
      (new-streak (if successful (+ (get current-streak current-performance) u1) u0))
      (new-longest (max (get longest-streak current-performance) new-streak))
      (new-tier (calculate-performance-tier new-successful new-success-rate))
      (current-block burn-block-height)
    )
    (map-set referrer-performance referrer
      {
        total-referrals: new-total,
        successful-hires: new-successful,
        success-rate: new-success-rate,
        current-tier: new-tier,
        total-rewards-earned: (get total-rewards-earned current-performance),
        current-streak: new-streak,
        longest-streak: new-longest,
        last-successful-hire: (if successful current-block (get last-successful-hire current-performance))
      }
    )
    (ok true)
  )
)

;; Calculate performance tier based on metrics
(define-private (calculate-performance-tier (successful-hires uint) (success-rate uint))
  (if (and (>= successful-hires performance-tier-gold) (>= success-rate success-rate-threshold-gold))
    u3
    (if (and (>= successful-hires performance-tier-silver) (>= success-rate success-rate-threshold-silver))
      u2
      (if (and (>= successful-hires performance-tier-bronze) (>= success-rate success-rate-threshold-bronze))
        u1
        u0
      )
    )
  )
)

;; Distribute referral reward when hire is verified
(define-public (distribute-referral-reward (referral-id uint))
  (let
    (
      (referral-info (unwrap! (map-get? referrals referral-id) err-invalid-referral))
      (job-info (unwrap! (map-get? jobs (get job-id referral-info)) err-invalid-job))
      (hire-info (unwrap! (map-get? hires {job-id: (get job-id referral-info), candidate: (get candidate referral-info)}) err-invalid-application))
      (reward-calc (calculate-referral-reward (get referrer referral-info) (get reward job-info)))
      (current-block burn-block-height)
    )
    (asserts! (get verified hire-info) err-unauthorized)
    (asserts! (not (get reward-paid hire-info)) err-already-hired)
    (asserts! (is-none (map-get? referral-rewards referral-id)) err-invalid-referral)
    
    ;; Store reward calculation details
    (map-set referral-rewards referral-id
      {
        referral-id: referral-id,
        base-reward: (get base-reward reward-calc),
        tier-multiplier: (get tier-multiplier reward-calc),
        streak-bonus: (get streak-bonus reward-calc),
        total-reward: (get total-reward reward-calc),
        distributed: true,
        distribution-block: current-block
      }
    )
    
    ;; Transfer reward to referrer
    (try! (as-contract (stx-transfer? (get total-reward reward-calc) tx-sender (get referrer referral-info))))
    
    ;; Update hire record
    (map-set hires {job-id: (get job-id referral-info), candidate: (get candidate referral-info)}
      (merge hire-info {reward-paid: true})
    )
    
    ;; Update referrer performance and earnings
    (unwrap-panic (update-referrer-performance (get referrer referral-info) true))
    (map-set user-earnings (get referrer referral-info)
      (+ (default-to u0 (map-get? user-earnings (get referrer referral-info))) (get total-reward reward-calc)))
    
    ;; Update referrer performance total rewards
    (let
      (
        (current-perf (unwrap-panic (map-get? referrer-performance (get referrer referral-info))))
      )
      (map-set referrer-performance (get referrer referral-info)
        (merge current-perf {total-rewards-earned: (+ (get total-rewards-earned current-perf) (get total-reward reward-calc))})
      )
    )
    
    (ok (get total-reward reward-calc))
  )
)

;; Penalize referrer for failed/disputed referral
(define-public (penalize-referrer (referrer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (unwrap-panic (update-referrer-performance referrer false))
    (ok true)
  )
)

;; REPUTATION SYSTEM FUNCTIONS

;; Rate user after interaction
(define-public (rate-user (rated-user principal) (rating uint) (interaction-type (string-ascii 20)) (interaction-id uint) (comment (string-ascii 200)))
  (let
    (
      (rating-id (var-get next-rating-id))
      (current-block burn-block-height)
    )
    (asserts! (and (>= rating min-rating) (<= rating max-rating)) err-invalid-rating)
    (asserts! (not (is-eq tx-sender rated-user)) err-self-rating)
    (asserts! (is-none (map-get? interaction-ratings {interaction-type: interaction-type, interaction-id: interaction-id, rater: tx-sender})) err-already-rated)
    
    ;; Verify interaction exists and rater was involved
    (asserts! (verify-interaction-eligibility tx-sender rated-user interaction-type interaction-id) err-no-interaction)
    
    (map-set user-ratings rating-id
      {
        rater: tx-sender,
        rated-user: rated-user,
        rating: rating,
        interaction-type: interaction-type,
        interaction-id: interaction-id,
        comment: comment,
        created-at: current-block
      }
    )
    
    (map-set interaction-ratings {interaction-type: interaction-type, interaction-id: interaction-id, rater: tx-sender} rating-id)
    (var-set next-rating-id (+ rating-id u1))
    
    ;; Update user rating summary
    (unwrap-panic (update-user-rating-summary rated-user rating))
    
    ;; Award bonus reputation points for quality ratings (4-5 stars)
    (if (>= rating u4)
      (unwrap-panic (update-reputation rated-user quality-rating-bonus))
      true
    )
    
    (ok rating-id)
  )
)

;; Update user reputation points
(define-private (update-reputation (user principal) (points uint))
  (begin
    (map-set user-reputation user 
      (+ (default-to u0 (map-get? user-reputation user)) points))
    (ok true)
  )
)

;; Deduct reputation points (for disputes, violations)
(define-public (deduct-reputation (user principal) (points uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let 
      (
        (current-rep (default-to u0 (map-get? user-reputation user)))
      )
      (map-set user-reputation user 
        (if (> current-rep points) (- current-rep points) u0))
      (ok true)
    )
  )
)

;; Update user rating summary
(define-private (update-user-rating-summary (user principal) (new-rating uint))
  (let
    (
      (current-summary (default-to 
        {total-ratings: u0, average-rating: u0, five-star: u0, four-star: u0, three-star: u0, two-star: u0, one-star: u0, reputation-points: u0}
        (map-get? user-rating-summary user)))
      (new-total (+ (get total-ratings current-summary) u1))
      (new-five (if (is-eq new-rating u5) (+ (get five-star current-summary) u1) (get five-star current-summary)))
      (new-four (if (is-eq new-rating u4) (+ (get four-star current-summary) u1) (get four-star current-summary)))
      (new-three (if (is-eq new-rating u3) (+ (get three-star current-summary) u1) (get three-star current-summary)))
      (new-two (if (is-eq new-rating u2) (+ (get two-star current-summary) u1) (get two-star current-summary)))
      (new-one (if (is-eq new-rating u1) (+ (get one-star current-summary) u1) (get one-star current-summary)))
      (current-rep-points (default-to u0 (map-get? user-reputation user)))
    )
    (map-set user-rating-summary user
      {
        total-ratings: new-total,
        average-rating: (/ (+ (* (get five-star current-summary) u5) (* (get four-star current-summary) u4) (* (get three-star current-summary) u3) (* (get two-star current-summary) u2) (* (get one-star current-summary) u1) new-rating) new-total),
        five-star: new-five,
        four-star: new-four,
        three-star: new-three,
        two-star: new-two,
        one-star: new-one,
        reputation-points: current-rep-points
      }
    )
    (ok true)
  )
)

;; Verify if user can rate another user for specific interaction
(define-private (verify-interaction-eligibility (rater principal) (rated-user principal) (interaction-type (string-ascii 20)) (interaction-id uint))
  (if (is-eq interaction-type "referral")
    (verify-referral-interaction rater rated-user interaction-id)
    (if (is-eq interaction-type "hire")
      (verify-hire-interaction rater rated-user interaction-id)
      (if (is-eq interaction-type "job")
        (verify-job-interaction rater rated-user interaction-id)
        false
      )
    )
  )
)

;; Verify referral interaction eligibility
(define-private (verify-referral-interaction (rater principal) (rated-user principal) (referral-id uint))
  (match (map-get? referrals referral-id)
    referral-info 
    (or 
      (and (is-eq rater (get candidate referral-info)) (is-eq rated-user (get referrer referral-info)))
      (and (is-eq rater (get referrer referral-info)) (is-eq rated-user (get candidate referral-info)))
    )
    false
  )
)

;; Verify hire interaction eligibility  
(define-private (verify-hire-interaction (rater principal) (rated-user principal) (job-id uint))
  (match (map-get? jobs job-id)
    job-info
    (or
      (is-eq rater (get employer job-info))
      (is-some (map-get? hires {job-id: job-id, candidate: rater}))
    )
    false
  )
)

;; Verify job interaction eligibility
(define-private (verify-job-interaction (rater principal) (rated-user principal) (job-id uint))
  (match (map-get? jobs job-id)
    job-info
    (or
      (is-eq rater (get employer job-info))
      (is-some (map-get? job-applications {job-id: job-id, applicant: rater}))
    )
    false
  )
)

;; Enhanced dispute with reputation penalties
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

;; Resolve dispute with reputation impact
(define-public (resolve-dispute (dispute-id uint))
  (let
    (
      (dispute-info (unwrap! (map-get? disputes dispute-id) err-dispute-not-found))
      (current-block burn-block-height)
      (referral-info (unwrap! (map-get? referrals (get referral-id dispute-info)) err-invalid-referral))
    )
    (asserts! (>= current-block (get voting-end dispute-info)) err-voting-ended)
    (asserts! (not (get resolved dispute-info)) err-invalid-vote)
    
    (map-set disputes dispute-id
      (merge dispute-info {resolved: true})
    )
    
    ;; If dispute resolved against user, deduct reputation points
    (if (> (get yes-votes dispute-info) (get no-votes dispute-info))
      (begin
        (unwrap-panic (deduct-reputation-unsafe (get referrer referral-info) dispute-penalty-points))
        (unwrap-panic (deduct-reputation-unsafe (get candidate referral-info) dispute-penalty-points))
      )
      true
    )
    
    (ok (> (get yes-votes dispute-info) (get no-votes dispute-info)))
  )
)

;; Private function for reputation deduction (internal use)
(define-private (deduct-reputation-unsafe (user principal) (points uint))
  (let 
    (
      (current-rep (default-to u0 (map-get? user-reputation user)))
    )
    (map-set user-reputation user 
      (if (> current-rep points) (- current-rep points) u0))
    (ok true)
  )
)

;; READ-ONLY FUNCTIONS

;; Get user's complete reputation profile
(define-read-only (get-user-reputation-profile (user principal))
  {
    reputation-points: (default-to u0 (map-get? user-reputation user)),
    rating-summary: (default-to 
      {total-ratings: u0, average-rating: u0, five-star: u0, four-star: u0, three-star: u0, two-star: u0, one-star: u0, reputation-points: u0}
      (map-get? user-rating-summary user)),
    performance-tier: (default-to u0 (map-get? user-performance-tier user)),
    successful-hires: (default-to u0 (map-get? user-successful-hires user)),
    total-earnings: (default-to u0 (map-get? user-earnings user)),
    can-access-premium: (>= (default-to u0 (map-get? user-reputation user)) min-reputation-for-premium)
  }
)

;; Get rating details
(define-read-only (get-rating (rating-id uint))
  (map-get? user-ratings rating-id)
)

(define-read-only (get-application (application-id uint))
  (map-get? applications application-id)
)

;; Get user's received ratings
(define-read-only (get-user-ratings (user principal) (limit uint))
  (ok "Use external indexer for rating history")
)

;; Check if user can apply to job based on reputation
(define-read-only (can-apply-to-job (user principal) (job-id uint))
  (match (map-get? jobs job-id)
    job-info
    {
      can-apply: (>= (default-to u0 (map-get? user-reputation user)) (get min-reputation job-info)),
      user-reputation: (default-to u0 (map-get? user-reputation user)),
      required-reputation: (get min-reputation job-info)
    }
    {can-apply: false, user-reputation: u0, required-reputation: u0}
  )
)

;; Original read-only functions
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
    total-earnings: (default-to u0 (map-get? user-earnings user)),
    reputation-points: (default-to u0 (map-get? user-reputation user))
  }
)

(define-read-only (get-contract-balance)
  (var-get contract-balance)
)

(define-read-only (get-next-ids)
  {
    next-referral-id: (var-get next-referral-id),
    next-job-id: (var-get next-job-id),
    next-dispute-id: (var-get next-dispute-id),
    next-application-id: (var-get next-application-id),
    next-rating-id: (var-get next-rating-id)
  }
)

;; JOB REFERRAL REWARDS SYSTEM READ-ONLY FUNCTIONS

;; Get referrer performance metrics
(define-read-only (get-referrer-performance (referrer principal))
  (default-to 
    {total-referrals: u0, successful-hires: u0, success-rate: u0, current-tier: u0, total-rewards-earned: u0, current-streak: u0, longest-streak: u0, last-successful-hire: u0}
    (map-get? referrer-performance referrer))
)

;; Get referral reward details
(define-read-only (get-referral-reward-details (referral-id uint))
  (map-get? referral-rewards referral-id)
)

;; Calculate estimated reward for a referrer
(define-read-only (estimate-referral-reward (referrer principal) (job-reward uint))
  (calculate-referral-reward referrer job-reward)
)

;; Get performance tier name
(define-read-only (get-tier-name (tier uint))
  (if (is-eq tier u3)
    "Gold"
    (if (is-eq tier u2)
      "Silver"
      (if (is-eq tier u1)
        "Bronze"
        "Unranked"
      )
    )
  )
)

;; Get leaderboard data (top referrers by rewards earned)
(define-read-only (get-referrer-leaderboard-entry (referrer principal))
  (let
    (
      (performance (get-referrer-performance referrer))
    )
    {
      referrer: referrer,
      tier: (get current-tier performance),
      tier-name: (get-tier-name (get current-tier performance)),
      total-rewards: (get total-rewards-earned performance),
      successful-hires: (get successful-hires performance),
      success-rate: (get success-rate performance),
      current-streak: (get current-streak performance),
      longest-streak: (get longest-streak performance)
    }
  )
)

;; Check reward system constants
(define-read-only (get-reward-system-constants)
  {
    base-referral-reward: base-referral-reward,
    tier-thresholds: {
      bronze: performance-tier-bronze,
      silver: performance-tier-silver,
      gold: performance-tier-gold
    },
    success-rate-thresholds: {
      bronze: success-rate-threshold-bronze,
      silver: success-rate-threshold-silver,
      gold: success-rate-threshold-gold
    },
    reward-multipliers: {
      bronze: reward-multiplier-bronze,
      silver: reward-multiplier-silver,
      gold: reward-multiplier-gold
    },
    streak-bonus: {
      threshold: bonus-streak-threshold,
      multiplier: streak-bonus-multiplier
    }
  }
)
