use loja_tech;

DROP PROCEDURE IF EXISTS atualizar_preco_categoria;

DELIMITER $$

CREATE PROCEDURE atualizar_preco_categoria(
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
END $$

DELIMITER ;

CALL atualizar_preco_categoria(1, 10.00, @qtd, @msg);

SELECT @qtd AS produtos_alterados, @msg AS mensagem;

CALL atualizar_preco_categoria(1, -60.00, @qtd, @msg);

SELECT @qtd AS produtos_alterados, @msg AS mensagem;

