// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/**
* @title KipuBank
* @author Gustavo R. Paz
* @dev Smart contract para gestionar un banco sencillo donde los usuarios pueden depositar y retirar ETH.
*/
contract KipuBank {

    /*//////////////////////////////
          Variables de estado
    ///////////////////////////////*/

    /// @notice propietario del contrato
    address public immutable owner;

    /// @notice Límite por transacción de retiro (en wei)
    uint256 public immutable withdrawLimit = 1e14; 

    /// @notice Mapping para relacionar las direcciones con la información de los usuarios
    mapping(address => uint256) private balances;

    /// @notice Limite global de depositos;
    uint256 public treasuryBalance = 0;

    /// @notice Limite global de depositos;
    uint256 public immutable bankCap;

    /// @notice contador retiros
    uint128 public withdrawalCount = 0;

    //@notice contador depositos
    uint128 public depositosCount = 0;

    /// @notice Indica si el contrato está bloqueado para nuevas transacciones.
    bool private lock = false;

    /*//////////////////////////////
            Errores
    ///////////////////////////////*/

    /// @notice Error personalizado para manejo de fondos insuficientes
    error InsufficientUserBalance(uint256 requested, uint256 available);

    /// @notice Error personalizado para manejo de valores no válidos
    error ValueError(uint256 value);

    /// @notice Error personalizado para manejo de llamadas no autorizadas
    error Reentrancy();

    /// @notice Error personalizado para manejo de excedentes del límite del banco
    error BankCapLimitExceeded(address caller, uint256 attemptedDeposit, uint256 bankCap);

    /// @notice Error personalizado para manejo de errores en el limite de retiro
    error WithdrawalLimitExceeded(address caller, uint256 attemptedWithdrawal);

    /// @notice Error personalizado para manejo de errores en retiros con valor cero
    error WithdrawalAmountError(address caller, uint256 attemptedWithdrawal);

    /// @notice Error personalizado para manejo de retiros al transferir
    error WithdrawalTransferError(address caller, uint256 _amount);

    /// @notice Error personalizado para manejo de errores en los depositos
    error DepositAmountMismatch(address caller, uint256 expectedValue, uint256 _amount);

    /// @notice Error personalizado para manejo de errores en el los depositos
    error DepositFailed(address caller, uint256 value);

    /// @notice Error personalizado para manejo de errores en el los depositos fallbacks (receive)
    error ReceiveFallbackDepositError(address caller, uint256 value);

    /// @notice Error personalizado para manejo de errores en el los depositos fallbacks (fallback)
    error FallbackDepositError(address caller, uint256 value);

    /// @notice Error personalizado para manejo de errores en los parametros del constructor
    error ConstructorError(string parameter);

    /*//////////////////////////////
            Eventos
    ///////////////////////////////*/

    /// @notice Evento que se emite cuando se realiza un depósito
    event Deposit(address indexed _user, uint256 _amount, uint256 _newBalance);

    /// @notice Evento que se emite cuando se realiza un retiro
    event Withdrawal(address indexed _user, uint256 _amount, uint256 _newBalance);

    /*//////////////////////////////
            Modificadores
    ///////////////////////////////*/

    /// @notice Modificador para prevenir la reentrancia
    modifier nonReentrant() {
        if (lock) revert Reentrancy();
        lock = true;
        _;
        lock = false;
    }
    /// @notice Modificador para verificar si no se ah excedido el limite del banco y actualiza el balance
    modifier bankCapCheck() {
        uint256 newBalance = treasuryBalance + msg.value;
        if (newBalance > bankCap) revert BankCapLimitExceeded(msg.sender, msg.value, bankCap);
        treasuryBalance = newBalance;
        _;
    }

    /**
     * @dev Constructor del contrato
     * @param _bankCap El límite máximo de fondos que el banco puede manejar (en wei)
     */
    constructor(uint256 _bankCap) {
        if (_bankCap == 0) revert ConstructorError("_bankCap");
        bankCap = _bankCap;
        owner = msg.sender;
    }

    /*//////////////////////////////
            Funciones
    ///////////////////////////////*/

    /**
     * @dev Función para verificar el saldo del usuario
     * @return El saldo del usuario en wei
     */
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    /**
     * @dev Función para depositar ETH en la cuenta del usuario
     */
    function deposit(uint256 _amount) external payable {
        if (_amount != msg.value) revert DepositAmountMismatch(msg.sender, msg.value, _amount);
        bool success = depositFallback();
        if (!success) revert DepositFailed(msg.sender, msg.value);
    }

    /**
     * @dev Función para retirar ETH de la cuenta del usuario
     * @param amount La cantidad a retirar (en wei)
     */
    function withdraw(uint256 amount) public nonReentrant {
        if (amount == 0) revert WithdrawalAmountError(msg.sender, amount);
        // Cache the balance to avoid multiple storage reads
        uint256 userBalance = balances[msg.sender];
        
        if (amount > withdrawLimit) revert WithdrawalLimitExceeded(msg.sender, amount);
        if (amount > userBalance) revert InsufficientUserBalance(amount, userBalance);

        // Restar la cantidad retirada al balance del usuario
        //unchecked {
        balances[msg.sender] = userBalance - amount;
        //}

        // Restar el balance de la tesorería
        treasuryBalance -= amount;

        // Transferir la cantidad al usuario
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert WithdrawalTransferError(msg.sender, amount);

        // Emitir evento de retiro
        emit Withdrawal(msg.sender, amount, userBalance - amount);

        // aumentar contador retiros
        withdrawalCount++;
    }

    /// @notice funcion privada para manejar el depósito de ETH en caso de que entre en las funciones fallback
    function depositFallback() private bankCapCheck returns (bool) { 
        if (msg.value == 0) return false;
        
        uint256 userBalance = balances[msg.sender];
        
        balances[msg.sender] = userBalance + msg.value;
        
        // emitir evento deDeposito
        emit Deposit(msg.sender, msg.value, userBalance + msg.value);
        
        // aumentar contador depositos
        depositosCount++;
        return true;
    }

    /*///////////////////////////////
            Fallbacks
    ///////////////////////////////*/

    /// @notice Función para aceptar ETH directo (sin datos)
    receive() external payable {
        bool success = depositFallback();
        if (!success) revert ReceiveFallbackDepositError(msg.sender, msg.value);
    }

    /// @notice Fallback para llamadas con datos inesperados
    fallback() external payable {
        bool success = depositFallback();
        if (!success) revert FallbackDepositError(msg.sender, msg.value);
    }
}
