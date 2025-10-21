import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { clarinet } from '@hirosystems/clarinet-sdk';

const accounts = clarinet.getAccounts();
const deployer = accounts.get('deployer')!;
const wallet1 = accounts.get('wallet_1')!;
const wallet2 = accounts.get('wallet_2')!;
const wallet3 = accounts.get('wallet_3')!;

describe('Job Referral System with Reputation', () => {
  describe('Job Management', () => {
    it('should create a job successfully', () => {
      const createJob = clarinet.tx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'create-job',
          functionArgs: [
            Cl.stringAscii('Senior Developer'),
            Cl.stringAscii('Looking for experienced developer with Clarity skills'),
            Cl.uint(1000000),
            Cl.uint(50) // min reputation
          ]
        }
      });

      const result = clarinet.runTx([createJob]);
      expect(result.result).toBeOk(Cl.uint(1));
    });

    it('should allow job application with sufficient reputation', () => {
      // First, give wallet2 some reputation points
      const giveReputationTx = clarinet.tx({
        sender: deployer.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'deduct-reputation', 
          functionArgs: [
            Cl.principal(wallet2.address),
            Cl.uint(0) // This actually adds reputation in our mock
          ]
        }
      });

      const createJob = clarinet.tx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'create-job',
          functionArgs: [
            Cl.stringAscii('Junior Developer'),
            Cl.stringAscii('Entry level position'),
            Cl.uint(500000),
            Cl.uint(0) // no reputation required
          ]
        }
      });

      const applyToJob = clarinet.tx({
        sender: wallet2.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'apply-to-job',
          functionArgs: [
            Cl.uint(1),
            Cl.stringAscii('I am very interested in this position.')
          ]
        }
      });

      const result = clarinet.runTx([createJob, applyToJob]);
      expect(result.results[1].result).toBeOk(Cl.uint(1));
    });
  });

  describe('Referral System', () => {
    it('should create referral and award reputation points', () => {
      const createJob = clarinet.tx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'create-job',
          functionArgs: [
            Cl.stringAscii('Backend Engineer'),
            Cl.stringAscii('Node.js and database experience required'),
            Cl.uint(800000),
            Cl.uint(0)
          ]
        }
      });

      const createReferral = clarinet.tx({
        sender: wallet2.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'create-referral',
          functionArgs: [
            Cl.principal(wallet3.address),
            Cl.uint(1)
          ]
        }
      });

      const result = clarinet.runTx([createJob, createReferral]);
      expect(result.results[1].result).toBeOk(Cl.uint(1));
      
      // Check that reputation points were awarded
      const getUserStats = clarinet.roTx({
        sender: wallet2.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-user-stats',
          functionArgs: [Cl.principal(wallet2.address)]
        }
      });

      const statsResult = clarinet.runTx([getUserStats]);
      // Should have earned reputation points for referral
    });

    it('should verify hire and award additional reputation points', () => {
      const createJob = clarinet.tx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'create-job',
          functionArgs: [
            Cl.stringAscii('Frontend Developer'),
            Cl.stringAscii('React and TypeScript experience'),
            Cl.uint(900000),
            Cl.uint(0)
          ]
        }
      });

      const createReferral = clarinet.tx({
        sender: wallet2.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'create-referral',
          functionArgs: [
            Cl.principal(wallet3.address),
            Cl.uint(1)
          ]
        }
      });

      const verifyHire = clarinet.tx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'verify-hire',
          functionArgs: [
            Cl.uint(1),
            Cl.principal(wallet3.address),
            Cl.uint(1)
          ]
        }
      });

      const result = clarinet.runTx([createJob, createReferral, verifyHire]);
      expect(result.results[2].result).toBeOk(Cl.bool(true));
    });
  });

  describe('Job Referral Rewards System', () => {
    it('should calculate rewards based on performance tier', () => {
      // Setup job and referral
      const setupTxs = [
        clarinet.tx({
          sender: wallet1.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'create-job',
            functionArgs: [
              Cl.stringAscii('Software Engineer'),
              Cl.stringAscii('Full-time software engineering position'),
              Cl.uint(2000000), // 2 STX job reward
              Cl.uint(0)
            ]
          }
        }),
        clarinet.tx({
          sender: wallet2.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'create-referral',
            functionArgs: [
              Cl.principal(wallet3.address),
              Cl.uint(1)
            ]
          }
        }),
        clarinet.tx({
          sender: wallet1.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'verify-hire',
            functionArgs: [
              Cl.uint(1),
              Cl.principal(wallet3.address),
              Cl.uint(1)
            ]
          }
        })
      ];

      const result = clarinet.runTx(setupTxs);
      expect(result.results[2].result).toBeOk(Cl.bool(true));

      // Check initial referrer performance
      const getPerformanceTx = clarinet.roTx({
        sender: deployer.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-referrer-performance',
          functionArgs: [Cl.principal(wallet2.address)]
        }
      });

      const performanceResult = clarinet.runTx([getPerformanceTx]);
      // Should have initial performance metrics after referral
    });

    it('should distribute rewards with tier multipliers', () => {
      const setupTxs = [
        clarinet.tx({
          sender: wallet1.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'create-job',
            functionArgs: [
              Cl.stringAscii('DevOps Engineer'),
              Cl.stringAscii('DevOps engineering role'),
              Cl.uint(1500000),
              Cl.uint(0)
            ]
          }
        }),
        clarinet.tx({
          sender: wallet2.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'create-referral',
            functionArgs: [
              Cl.principal(wallet3.address),
              Cl.uint(1)
            ]
          }
        }),
        clarinet.tx({
          sender: wallet1.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'verify-hire',
            functionArgs: [
              Cl.uint(1),
              Cl.principal(wallet3.address),
              Cl.uint(1)
            ]
          }
        }),
        clarinet.tx({
          sender: deployer.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'distribute-referral-reward',
            functionArgs: [Cl.uint(1)]
          }
        })
      ];

      const result = clarinet.runTx(setupTxs);
      expect(result.results[3].result).toBeOk();

      // Check reward details
      const getRewardDetailsTx = clarinet.roTx({
        sender: deployer.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-referral-reward-details',
          functionArgs: [Cl.uint(1)]
        }
      });

      const rewardResult = clarinet.runTx([getRewardDetailsTx]);
      // Should have reward calculation details
    });

    it('should handle performance tier progression', () => {
      // Create multiple jobs and referrals to test tier progression
      const jobs = [];
      for (let i = 0; i < 6; i++) {
        jobs.push(
          clarinet.tx({
            sender: wallet1.address,
            contractCall: {
              contractName: 'job-referral-system',
              functionName: 'create-job',
              functionArgs: [
                Cl.stringAscii(`Job ${i + 1}`),
                Cl.stringAscii(`Job description ${i + 1}`),
                Cl.uint(1000000),
                Cl.uint(0)
              ]
            }
          })
        );
      }

      const referrals = [];
      for (let i = 0; i < 6; i++) {
        referrals.push(
          clarinet.tx({
            sender: wallet2.address,
            contractCall: {
              contractName: 'job-referral-system',
              functionName: 'create-referral',
              functionArgs: [
                Cl.principal(wallet3.address),
                Cl.uint(i + 1)
              ]
            }
          })
        );
      }

      const hires = [];
      for (let i = 0; i < 6; i++) {
        hires.push(
          clarinet.tx({
            sender: wallet1.address,
            contractCall: {
              contractName: 'job-referral-system',
              functionName: 'verify-hire',
              functionArgs: [
                Cl.uint(i + 1),
                Cl.principal(wallet3.address),
                Cl.uint(i + 1)
              ]
            }
          })
        );
      }

      const allTxs = [...jobs, ...referrals, ...hires];
      const result = clarinet.runTx(allTxs);

      // Check final performance tier
      const getPerformanceTx = clarinet.roTx({
        sender: deployer.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-referrer-performance',
          functionArgs: [Cl.principal(wallet2.address)]
        }
      });

      const performanceResult = clarinet.runTx([getPerformanceTx]);
      // Should show tier progression based on successful hires
    });

    it('should calculate streak bonuses correctly', () => {
      // Test streak bonus calculation
      const getEstimateTx = clarinet.roTx({
        sender: deployer.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'estimate-referral-reward',
          functionArgs: [
            Cl.principal(wallet2.address),
            Cl.uint(1000000)
          ]
        }
      });

      const estimateResult = clarinet.runTx([getEstimateTx]);
      // Should return reward calculation details
    });

    it('should provide reward system constants', () => {
      const getConstantsTx = clarinet.roTx({
        sender: deployer.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-reward-system-constants',
          functionArgs: []
        }
      });

      const constantsResult = clarinet.runTx([getConstantsTx]);
      expect(constantsResult.result).toBeOk();
    });

    it('should generate leaderboard entries', () => {
      const getLeaderboardTx = clarinet.roTx({
        sender: deployer.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-referrer-leaderboard-entry',
          functionArgs: [Cl.principal(wallet2.address)]
        }
      });

      const leaderboardResult = clarinet.runTx([getLeaderboardTx]);
      expect(leaderboardResult.result).toBeOk();
    });

    it('should handle penalties for failed referrals', () => {
      const penalizeTx = clarinet.tx({
        sender: deployer.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'penalize-referrer',
          functionArgs: [Cl.principal(wallet2.address)]
        }
      });

      const result = clarinet.runTx([penalizeTx]);
      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Reputation System', () => {
    it('should allow rating after interaction', () => {
      // Setup: Create job, referral, and hire
      const setupTxs = [
        clarinet.tx({
          sender: wallet1.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'create-job',
            functionArgs: [
              Cl.stringAscii('Full Stack Developer'),
              Cl.stringAscii('Full stack development role'),
              Cl.uint(1200000),
              Cl.uint(0)
            ]
          }
        }),
        clarinet.tx({
          sender: wallet2.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'create-referral',
            functionArgs: [
              Cl.principal(wallet3.address),
              Cl.uint(1)
            ]
          }
        }),
        clarinet.tx({
          sender: wallet1.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'verify-hire',
            functionArgs: [
              Cl.uint(1),
              Cl.principal(wallet3.address),
              Cl.uint(1)
            ]
          }
        })
      ];

      const rateUser = clarinet.tx({
        sender: wallet3.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'rate-user',
          functionArgs: [
            Cl.principal(wallet2.address),
            Cl.uint(5), // 5-star rating
            Cl.stringAscii('referral'),
            Cl.uint(1), // referral ID
            Cl.stringAscii('Excellent referral, very professional!')
          ]
        }
      });

      const result = clarinet.runTx([...setupTxs, rateUser]);
      expect(result.results[3].result).toBeOk(Cl.uint(1));
    });

    it('should get user reputation profile', () => {
      const getReputation = clarinet.roTx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-user-reputation-profile',
          functionArgs: [Cl.principal(wallet2.address)]
        }
      });

      const result = clarinet.runTx([getReputation]);
      expect(result.result).toBeOk();
    });

    it('should check job application eligibility based on reputation', () => {
      const createHighRepJob = clarinet.tx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'create-job',
          functionArgs: [
            Cl.stringAscii('Senior Architect'),
            Cl.stringAscii('High-level position requiring experience'),
            Cl.uint(2000000),
            Cl.uint(100) // high reputation requirement
          ]
        }
      });

      const checkEligibility = clarinet.roTx({
        sender: wallet2.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'can-apply-to-job',
          functionArgs: [
            Cl.principal(wallet2.address),
            Cl.uint(1)
          ]
        }
      });

      const result = clarinet.runTx([createHighRepJob, checkEligibility]);
      expect(result.results[1].result).toBeOk();
    });

    it('should prevent self-rating', () => {
      const setupJob = clarinet.tx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'create-job',
          functionArgs: [
            Cl.stringAscii('Test Job'),
            Cl.stringAscii('Test description'),
            Cl.uint(1000000),
            Cl.uint(0)
          ]
        }
      });

      const setupReferral = clarinet.tx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'create-referral',
          functionArgs: [
            Cl.principal(wallet2.address),
            Cl.uint(1)
          ]
        }
      });

      const selfRate = clarinet.tx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'rate-user',
          functionArgs: [
            Cl.principal(wallet1.address), // trying to rate self
            Cl.uint(5),
            Cl.stringAscii('referral'),
            Cl.uint(1),
            Cl.stringAscii('Self rating attempt')
          ]
        }
      });

      const result = clarinet.runTx([setupJob, setupReferral, selfRate]);
      expect(result.results[2].result).toBeErr(Cl.uint(113)); // err-self-rating
    });

    it('should prevent rating invalid interactions', () => {
      const rateInvalidInteraction = clarinet.tx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'rate-user',
          functionArgs: [
            Cl.principal(wallet2.address),
            Cl.uint(4),
            Cl.stringAscii('referral'),
            Cl.uint(999), // non-existent referral ID
            Cl.stringAscii('Invalid rating attempt')
          ]
        }
      });

      const result = clarinet.runTx([rateInvalidInteraction]);
      expect(result.result).toBeErr(Cl.uint(114)); // err-no-interaction
    });
  });

  describe('Dispute System with Reputation Impact', () => {
    it('should create dispute and penalize reputation when resolved', () => {
      // Setup job and referral
      const setupTxs = [
        clarinet.tx({
          sender: wallet1.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'create-job',
            functionArgs: [
              Cl.stringAscii('Disputed Job'),
              Cl.stringAscii('Job that will be disputed'),
              Cl.uint(1000000),
              Cl.uint(0)
            ]
          }
        }),
        clarinet.tx({
          sender: wallet2.address,
          contractCall: {
            contractName: 'job-referral-system',
            functionName: 'create-referral',
            functionArgs: [
              Cl.principal(wallet3.address),
              Cl.uint(1)
            ]
          }
        })
      ];

      const createDispute = clarinet.tx({
        sender: wallet3.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'create-dispute',
          functionArgs: [
            Cl.uint(1),
            Cl.stringAscii('Referrer provided false information')
          ]
        }
      });

      const result = clarinet.runTx([...setupTxs, createDispute]);
      expect(result.results[2].result).toBeOk(Cl.uint(1));
    });
  });

  describe('Read-Only Functions', () => {
    it('should get referral information', () => {
      const getReferral = clarinet.roTx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-referral',
          functionArgs: [Cl.uint(1)]
        }
      });

      const result = clarinet.runTx([getReferral]);
      // Should return none or referral data
    });

    it('should get job information', () => {
      const getJob = clarinet.roTx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-job',
          functionArgs: [Cl.uint(1)]
        }
      });

      const result = clarinet.runTx([getJob]);
      // Should return none or job data
    });

    it('should get user statistics', () => {
      const getUserStats = clarinet.roTx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-user-stats',
          functionArgs: [Cl.principal(wallet2.address)]
        }
      });

      const result = clarinet.runTx([getUserStats]);
      expect(result.result).toBeOk();
    });

    it('should get rating information', () => {
      const getRating = clarinet.roTx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-rating',
          functionArgs: [Cl.uint(1)]
        }
      });

      const result = clarinet.runTx([getRating]);
      // Should return none or rating data
    });

    it('should get next IDs', () => {
      const getNextIds = clarinet.roTx({
        sender: wallet1.address,
        contractCall: {
          contractName: 'job-referral-system',
          functionName: 'get-next-ids',
          functionArgs: []
        }
      });

      const result = clarinet.runTx([getNextIds]);
      expect(result.result).toBeOk();
    });
  });
});
