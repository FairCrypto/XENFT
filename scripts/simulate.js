const { Contract, Wallet } = require("ethers")
const { JsonRpcProvider } = require('@ethersproject/providers')
const { NonceManager } = require('@ethersproject/experimental/lib/nonce-manager');

const xen = require("@faircrypto/xen-crypto/build/contracts/XENCrypto.json");
const torrent = require("../build/contracts/XENTorrent.json");
require("dotenv").config()

const accounts = [
    '0xBF82b72cf54F55413F74dAEeF0f3eB0A7F9c96A3',
    '0x968ce93805c98Fd6F1460Ff2248A06B3c73b61Df',
    '0x4795032CEfE9474157a7DF9f971297eC925b5669',
    '0xb4F101B54120d685Dd644324E9960D96b3f04284',
    '0x39ebd158B2fE92A88B72C923cea00554D10242d8',
    '0xcE8C2E8B669d9d161Cf08C128Aa6D80526e1B888',
    '0x8A366A33658E786ffa96950B4B0c525517514519',
    '0x93918A321c43A39A7E40e609aE417c58bAabE112',
    '0x35570601D82685e85C088662AED86A39A24a8694',
    '0xB882F04ca961912aC12ab61DF672864661224B5b',
    '0xf4996e90106637948007dc742ADb4774CD39b70a',
    '0xd967c3C5dFfb254d6B7B816e0Ca819B65244294b',
]

module.exports = async function(callback) {
    try {
        const provider = new JsonRpcProvider('http://127.0.0.1:8545');
        // const provider = new JsonRpcProvider('https://x1-fastnet.infrafc.org');
        const currentNet = 222222;
        // const currentNet = 4003;
        //const adminSigner = new Wallet(privateKeys[1], provider); // new Wallet(privateKeys[0], provider);
        // const adminSigner = new Wallet(process.env.LIVE_PK, provider); // new Wallet(privateKeys[0], provider);
        const adminSigner = new Wallet(process.env.SIM_PK, provider); // new Wallet(privateKeys[0], provider);
        const managedSigner = new NonceManager(adminSigner);
        const xenAddress = xen.networks[currentNet]?.address || '0xa754fDFa760857442F29c929765FcC9a6d8d6d22'
        const torrentAddress = torrent.networks[currentNet]?.address || '0x97dB4089d0FB3c346B0671E928668AaC7aAf81A1'
        console.log('using xen Address', xenAddress);
        console.log('using torrent Address', torrentAddress);

        const xenCrypto = new Contract(xenAddress, xen.abi, managedSigner);
        const xenTorrent = new Contract(torrentAddress, torrent.abi, managedSigner);
        // console.log('authors', await xenKnights.AUTHORS());

        // for await(const i of Array(20).fill(null).map((_, i) => i).slice(1)) {
        //    const res = await xenCrypto.claimRank(100, { gasLimit: 200_000, from: accounts[i] });
        //    await res.wait(2);
        //    console.log(i)
        // }

        console.time('bulk mint 200')
        const ids = Array(20).fill(null).map((_, i) => i);
        for await (const i of ids) {
            const vmus = 100; // Math.floor(Math.random() * 44) + 1;
            const term = Math.floor(Math.random() * 100) + 1;
            const gasLimit = Math.min(550_000 + 199_000 * (vmus - 1) + (10_000 * (i + 0)), 29_500_000);
            await xenTorrent.bulkClaimRank(vmus, term, { gasLimit });
                // .then(_ => _.wait());
            process.stdout.write('.');
        }
        process.stdout.write('\n');
        console.timeEnd('bulk mint 200')

    } catch (e) {
        console.log(e);
    } finally {
        callback();
    }
}
