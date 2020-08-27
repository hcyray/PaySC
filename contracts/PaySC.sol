pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Party.sol";

contract PaySC {
    using SafeMath for uint;

    // the unique service id
    uint serviceId = 0;

    // mapping from a service id to the service
    mapping(uint => Service) services;


    //parameters for LR
    uint w0=0;
    uint w1=1;
    uint w2=1;
    
    // time window
    uint w = 10;
    
    // discount rate;
    uint alpha = 2;
    // Party Contract
    Party party;
    // defines a service
    struct Service {
        uint value; // value of the contract
        uint createTime; // pcontract create time
        uint discountTime; // discount date
        uint dueTime; // due date
        uint payerID; // ID of payer
        uint payeeID; // ID of payee
        address payable payerAddr; // address of the payer
        address payable payeeAddr; // address of the payee
        uint collateral; // collateral for payer
        uint virtualCollateral; // virtual collateral
        uint state; // contract state
        uint credi;
        uint credj;
        uint round;
    }
    
    event ServiceSetup(uint id);
    event ProvidedPrepayment(uint id, uint amount);


    constructor(address _address) public {
        party = Party(_address);            
    } 


    function setupService(
        uint value,
        uint cost,
        uint createTime,
        uint discountTime,
        uint dueTime,
        uint payerID,
        uint payeeID
    ) public payable {
        
        if (!party.isLeagalParty(payerID) || !party.isLeagalParty(payeeID)){
            return;
        }

        address payable payerAddr = address(uint160(party.getAddress(payerID)));
        require(msg.sender == payerAddr, "Needs to be the payer.");

        party.removeContract(payerID,w);
        party.removeContract(payeeID,w);
        uint PD = w0+w1*uint(party.getRep(payerID))+w2*party.getIncome(payerID);
        PD = 1;
        uint collateral = value - (value-cost)/PD;
        uint virtualCollateral = value - collateral;
        if (virtualCollateral<0) {
            return;
        }
        
        // virtual collateral == value - collateral
        require(msg.value == value - virtualCollateral);

        services[serviceId] = Service(
            value,
            createTime,
            discountTime,
            dueTime,
            payerID,
            payeeID,
            payerAddr,
            address(uint160(party.getAddress(payeeID))),
            msg.value,
            virtualCollateral,
            2,
            value,
            0,
            0
        );

        party.addContract(payeeID, serviceId, 2, value, createTime, dueTime, 1);

        emit ServiceSetup(serviceId);
        serviceId = serviceId + 1;

        
    }

    function updateSC(uint id, uint r, uint credi, uint credj, bytes memory sigPayer, bytes memory sigPayee) public {
        
        require(r > services[id].round);

        bytes32 msgHash = keccak256(abi.encodePacked(r,credi,credj));
        require(party.verifySignature(msgHash, sigPayer, services[id].payerAddr), "Verfiication of Payer's siganture failed.");
        require(party.verifySignature(msgHash, sigPayee, services[id].payeeAddr), "Verfiication of Payee's siganture failed.");

        services[id].credi = credi;
        services[id].credj = credj;
        services[id].round = r;
    }

    function paySC(uint id, uint r, uint credi, uint credj,uint t) public payable {

        require(msg.sender == services[id].payerAddr, "Needs to be the payer.");
        require(r > services[id].round, "Not Maximum Round");
        require(credi == 0, "Not valid state");
        require(services[id].credi+services[id].credj == credj);
        uint payValue = credj;
        if (t < services[id].discountTime){
            payValue = payValue/alpha;
        } 
        
        require(msg.value + services[id].collateral >= payValue, "Not Enough Money.");

        services[id].value = credi+credj;
        services[id].payeeAddr.transfer(payValue);
        if (msg.value + services[id].collateral > payValue) {
            services[id].payerAddr.transfer(msg.value + services[id].collateral - payValue);
        }

        services[id].state = 1;
        party.addContract(services[id].payerID, id, 1, services[id].value, services[id].createTime, services[id].dueTime, 0);
        party.removeActiveContract(services[id].payeeID, id);
    }

    function disputeSC(uint id,  uint r, uint credi, uint credj,uint t) public {
        require(msg.sender == services[id].payeeAddr, "Needs to be the payee.");
        require(t>services[id].dueTime, "Not Due date.");
        require(services[id].state == 2, "Not Active Contract.");
        require(r==services[id].round, "Not Correct Round.");

        services[id].value = credi+credj;
        services[id].state = 3;
        services[id].payeeAddr.transfer(services[id].collateral);
        
        
        party.addContract(services[id].payerID, id, 3, services[id].value, services[id].createTime, services[id].dueTime, 0);
        party.removeActiveContract(services[id].payeeID, id);
    }

    function resolveSC(uint id, uint t) public payable {
        require(msg.sender == services[id].payerAddr, "Needs to be the payer.");
        require(t>services[id].dueTime, "Not Due date.");
        require(services[id].state == 3, "Not Unresolved Contract.");
        require(services[id].value == msg.value + services[id].collateral);

        services[id].payeeAddr.transfer(msg.value);
        services[id].state = 0;
        party.resolveContract(services[id].payerID, id);
    }

    function closeSC(uint id, uint t) public payable {
        
        require(t>services[id].dueTime, "Not Due date.");
        require(services[id].state == 0 || services[id].state == 1, "Not ready for close");
        
    }



    function currentOffChannelState(uint id) public view returns(uint r, uint credi, uint credj) {
        r = services[id].round;
        credi = services[id].credi;
        credj = services[id].credj;
    }

    function numOfVirtualCollateral(uint id) public view returns(uint) {
        return  services[id].virtualCollateral;
    }

 
}
