import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Límite global del banco (en wei)
const BANK_CAP = BigInt(1e15); // 0.001 ETH

// Propietario del contrato
const OWNER = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

export default buildModule("kipuBankModule", (m) => {

  // Dueño o sender del contrato (msg.sender) que se usara para deployar el contrato
  // en este caso se usa la cuenta 0 del hardhat node (hardhat trae 20 cuentas por defecto para testing)
  const bankCap = m.getParameter("bankCap", BANK_CAP);

  const kipuBank = m.contract("KipuBank",[bankCap], { from: OWNER });
  return { kipuBank };
});
