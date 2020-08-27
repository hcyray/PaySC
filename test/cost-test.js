const truffleAssert = require('truffle-assertions');
const Party = artifacts.require("Party");
const PaySC = artifacts.require("PaySC");

contract("cost", async accounts => {
    let payer = accounts[0];
    let payee = accounts[1];
    const PayerID = 0;
    const PayeeID = 1;
    
    it("party test", async () => {
        let party = await Party.deployed();

        // create party for payer
        let createPartyTx = await party.registerParty('payer license', payer, {from: payer});
        truffleAssert.eventEmitted(createPartyTx, 'PartyCreated', (ev) => {
            return ev.id.toNumber() === PayerID;
        });

        console.log(`registerPayerSuccess`);
        let registerGas = createPartyTx.receipt.gasUsed;
        console.log(`registerGas: ${registerGas}`);

        // create party for payee
        let createPartyPayeeTx = await party.registerParty('payee license', payee, {from: payee});
        truffleAssert.eventEmitted(createPartyPayeeTx, 'PartyCreated', (ev) => {
            return ev.id.toNumber() === PayeeID;
        });
        console.log(`registerPayeeSuccess`);

        // add uint id, uint scid, uint state, uint value, uint createtime,  uint duetime, uint role
        let addContractTx = await party.addContract(0, 2, 1, 10, 0, 2, 0, {from:payer});
        let addContractGas = addContractTx.receipt.gasUsed;
        console.log(`addContractGas: ${addContractGas}`);
        let addContract2Tx = await party.addContract(0, 1, 1, 100, 10, 30, 0, {from:payer});
        let addContractGas2 = addContract2Tx.receipt.gasUsed;
        console.log(`addContractGas2: ${addContractGas2}`);

        //remove uint x, uint id
        let removeContractTx = await party.removeContract(0, 15, {from:payer});
        let removeContractGas = removeContractTx.receipt.gasUsed;
        console.log(`removeContractGas: ${removeContractGas}`);
        let currentRep = await party.getRep(0);
        assert.equal(currentRep.toNumber(), 100)
    });
    
    it("PaySC test", async () => {
        let party = await Party.deployed();
        let paySC = await PaySC.deployed();
        
        //Parameter for a contract
        const VALUE  = 100;
        const COST  = 90;
        const COLLATERAL = 90;
        const SERVICE_ID = 0;
        const PAY_VALUE = 10;
        
        // is payer and payee exists
        let isExistsPartyTx = await party.isExists(PayerID, {from:payer});
        assert.equal(isExistsPartyTx, true);
        isExistsPartyTx = await party.isExists(PayeeID, {from:payee});
        assert.equal(isExistsPartyTx, true);

        
        // Setup
        let setupPaySCTx = await paySC.setupService(VALUE, COST, 15, 20, 25, PayerID, PayeeID, {from:payer, value: 90});
        truffleAssert.eventEmitted(setupPaySCTx, 'ServiceSetup', (ev) => {
            return ev.id.toNumber() === SERVICE_ID;
        });
        let setupPaySCGas = setupPaySCTx.receipt.gasUsed;
        console.log(`setupPaySCGas: ${setupPaySCGas}`);

        let askVCTx = await paySC.numOfVirtualCollateral(SERVICE_ID);
        assert.equal(askVCTx, 10);

        let currentStateTx = await paySC.currentOffChannelState(SERVICE_ID);
        console.log(`current off-channel state: round = ${currentStateTx.r}, credi = ${currentStateTx.credi}, credj = ${currentStateTx.credj}`);
        

 
        var msgHash = web3.utils.soliditySha3(1,80,20);
        var sigPayer = (await web3.eth.sign(msgHash, payer));
        var sigPayee = (await web3.eth.sign(msgHash, payee));

        //update the off channel state
        let updatePaySCTx = await paySC.updateSC(SERVICE_ID, 1, 80, 20, sigPayer, sigPayee);
        let updatePaySCTxGas = updatePaySCTx.receipt.gasUsed;
        console.log(`updatePaySCGas: ${updatePaySCTxGas}`);

        currentStateTx = await paySC.currentOffChannelState(SERVICE_ID);
        console.log(`current off-channel state: round = ${currentStateTx.r}, credi = ${currentStateTx.credi}, credj = ${currentStateTx.credj}`);

        //finalize the payment
        msgHash = web3.utils.soliditySha3(2,0,100);
        let payPaySCTx = await paySC.paySC(SERVICE_ID, 2, 0, 100, 22, {from:payer, value:100});
        let payPaySCTxGas = payPaySCTx.receipt.gasUsed;
        console.log(`payPaySCGas: ${payPaySCTxGas}`);

        // //dispute and resolve
        // let disputePaySCTx = await paySC.disputeSC(SERVICE_ID, 1, 80, 20, 30, {from:payee});
        // let disputePaySCTxGas = disputePaySCTx.receipt.gasUsed;
        // console.log(`disputePaySCGas: ${disputePaySCTxGas}`);

        // let resolvePaySCTx = await paySC.resolveSC(SERVICE_ID, 35, {from:payer, value:10});
        // let resolvePaySCTxGas = resolvePaySCTx.receipt.gasUsed;
        // console.log(`resolvePaySCTxGas: ${resolvePaySCTxGas}`);
    });
})

