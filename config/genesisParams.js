module.exports = {
    burnRates: [
        0n,
        10n,
        500n,
        1_000n,
        2_000n,
        5_000n,
        10_000n,
    ],
    rareLimits: [
        0,      // starts from 10_001
        0,      // starts from 10_001
        10_000, // starts from 6_001
        6_000,  // starts from 3_001
        3_000,  // starts from 1_001
        1_000,  // starts from 101
        100,    // starts from 1
    ],
    Series: {
        COLLECTOR:  0,
        LIMITED:    1,
        RARE:       2,
        EPIC:       3,
        LEGENDARY:  4,
        EXOTIC:     5,
        XUNICORN:   6,
    },
    forwarder: '0x0000000000000000000000000000000000000000',
    royaltyReceiver: '0x0000000000000000000000000000000000000000',
    startBlock: 0,
}

