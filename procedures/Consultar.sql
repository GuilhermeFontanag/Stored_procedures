DROP PROCEDURE IF EXISTS consultar_extrato_cliente;

DELIMITER $$

CREATE PROCEDURE consultar_extrato_cliente(
    IN p_id_cliente INT
)
BEGIN
    DECLARE v_cliente_existe INT DEFAULT 0;

    SELECT COUNT(*)
    INTO   v_cliente_existe
    FROM   clientes
    WHERE  id_cliente = p_id_cliente;

    IF v_cliente_existe = 0 THEN
        SELECT CONCAT('ERRO: Cliente com ID ', IFNULL(p_id_cliente, 'NULL'), ' não encontrado.') AS mensagem;
    ELSE
        SELECT
            nome,
            email,
            telefone,
            criado_em AS data_cadastro
        FROM  clientes
        WHERE id_cliente = p_id_cliente;

        SELECT
            id_pedido   AS numero_pedido,
            data_pedido,
            status,
            valor_total
        FROM  pedidos
        WHERE id_cliente = p_id_cliente
        ORDER BY data_pedido DESC;

        SELECT
            COUNT(id_pedido)               AS total_pedidos,
            IFNULL(SUM(valor_total), 0.00) AS valor_total_gasto,
            IFNULL(ROUND(AVG(valor_total), 2), 0.00) AS ticket_medio,
            MAX(data_pedido)               AS ultimo_pedido
        FROM  pedidos
        WHERE id_cliente = p_id_cliente
          AND status <> 'cancelado';
    END IF;
END $$

DELIMITER ;

CALL consultar_extrato_cliente(1);

CALL consultar_extrato_cliente(999);