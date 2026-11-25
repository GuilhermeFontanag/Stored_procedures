-- MySQL dump 10.13  Distrib 8.4.13, for Linux (x86_64)
--
-- Host: localhost    Database: loja_tech
-- ------------------------------------------------------
-- Server version	8.4.13-0ubuntu0.26.04.2

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping routines for database 'loja_tech'
--
/*!50003 DROP PROCEDURE IF EXISTS `atualizar_preco_categoria` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`example_user`@`localhost` PROCEDURE `atualizar_preco_categoria`(
    IN  p_id_categoria INT,
    IN  p_percentual   DECIMAL(5,2),
    OUT p_qtd_alterada INT,
    OUT p_mensagem     VARCHAR(255)
)
BEGIN
    DECLARE v_categoria_nome VARCHAR(100);
    DECLARE v_tipo_ajuste    VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_qtd_alterada = 0;
        SET p_mensagem = 'ERRO: Falha ao atualizar os preços da categoria. Operação revertida.';
    END;

    SET p_qtd_alterada = 0;

    IF p_percentual IS NULL OR p_percentual = 0 THEN
        SET p_mensagem = 'AVISO: O percentual de ajuste não pode ser nulo ou igual a 0%. Nenhuma alteração realizada.';

    ELSEIF p_percentual < -50.00 THEN
        SET p_mensagem = 'ERRO: O desconto máximo permitido é de 50% (valor mínimo: -50).';

    ELSEIF p_percentual > 100.00 THEN
        SET p_mensagem = 'ERRO: O aumento máximo permitido é de 100% (valor máximo: 100).';

    ELSE
        SELECT nome
        INTO   v_categoria_nome
        FROM   categorias
        WHERE  id_categoria = p_id_categoria
          AND  ativo = TRUE;

        IF v_categoria_nome IS NULL THEN
            SET p_mensagem = 'ERRO: Categoria não encontrada ou inativa.';
        ELSE
            START TRANSACTION;

            UPDATE produtos
            SET    preco = ROUND(preco * (1 + (p_percentual / 100)), 2)
            WHERE  id_categoria = p_id_categoria
              AND  ativo = TRUE;

            SET p_qtd_alterada = ROW_COUNT();

            SET v_tipo_ajuste = IF(p_percentual > 0, 'Aumento', 'Desconto');

            INSERT INTO log_operacoes (tabela_afetada, operacao, descricao)
            VALUES (
                'produtos',
                'UPDATE',
                CONCAT(
                    v_tipo_ajuste, ' de ', ABS(p_percentual), '% na categoria "',
                    v_categoria_nome, '" (ID: ', p_id_categoria,
                    ') | Produtos alterados: ', p_qtd_alterada
                )
            );

            COMMIT;

            SET p_mensagem = CONCAT(
                'Sucesso! ', p_qtd_alterada, ' produto(s) da categoria "',
                v_categoria_nome, '" atualizado(s) com ', p_percentual, '%.'
            );
        END IF;
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `consultar_extrato_cliente` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`example_user`@`localhost` PROCEDURE `consultar_extrato_cliente`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-24 21:08:47
