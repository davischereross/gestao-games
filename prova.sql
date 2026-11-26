DROP VIEW IF EXISTS vw_cronograma_partidas;
DROP VIEW IF EXISTS vw_painel_principal;

DROP TABLE IF EXISTS historico_partidas CASCADE;
DROP TABLE IF EXISTS partidas CASCADE;
DROP TABLE IF EXISTS modalidades CASCADE;
DROP TABLE IF EXISTS jogadores CASCADE;


CREATE TABLE jogadores (
    id_jogador SERIAL PRIMARY KEY,
    nickname VARCHAR(40) NOT NULL UNIQUE,
    email VARCHAR(120) NOT NULL UNIQUE,
    senha TEXT NOT NULL,
    status_conta VARCHAR(15) NOT NULL DEFAULT 'ATIVO',

    CHECK (status_conta IN ('ATIVO', 'INATIVO', 'BANIDO'))
);


CREATE TABLE modalidades (
    id_modalidade SERIAL PRIMARY KEY,
    nome VARCHAR(60) NOT NULL UNIQUE,
    categoria VARCHAR(30) NOT NULL,

    CHECK (categoria IN (
        'FPS',
        'BATTLE ROYALE',
        'MOBA',
        'ESPORTES',
        'OUTRO'
    ))
);


CREATE TABLE partidas (
    id_partida SERIAL PRIMARY KEY,
    titulo VARCHAR(100) NOT NULL,
    id_jogador INT NOT NULL,
    id_modalidade INT NOT NULL,
    data_agendamento TIMESTAMP NOT NULL,
    status_partida VARCHAR(20) NOT NULL DEFAULT 'AGENDADA',
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (id_jogador)
        REFERENCES jogadores(id_jogador),

    FOREIGN KEY (id_modalidade)
        REFERENCES modalidades(id_modalidade),

    CHECK (status_partida IN (
        'AGENDADA',
        'EM ANDAMENTO',
        'FINALIZADA',
        'CANCELADA'
    ))
);


CREATE TABLE historico_partidas (
    id_historico SERIAL PRIMARY KEY,
    id_partida INT NOT NULL,
    acao VARCHAR(50) NOT NULL,
    descricao TEXT,
    data_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (id_partida)
        REFERENCES partidas(id_partida)
);


CREATE OR REPLACE FUNCTION fn_validar_partida()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(15);
BEGIN

    SELECT status_conta
    INTO v_status
    FROM jogadores
    WHERE id_jogador = NEW.id_jogador;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Jogador nao encontrado.';
    END IF;

    IF v_status <> 'ATIVO' THEN
        RAISE EXCEPTION 'O jogador precisa estar ativo para participar.';
    END IF;

    NEW.data_criacao := CURRENT_TIMESTAMP;

    RETURN NEW;

END;
$$;


CREATE TRIGGER trg_validar_partida
BEFORE INSERT ON partidas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_partida();


CREATE OR REPLACE FUNCTION fn_registrar_historico_partida()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO historico_partidas (
        id_partida,
        acao,
        descricao
    )
    VALUES (
        NEW.id_partida,
        'PARTIDA CADASTRADA',
        'Cadastro automatico da partida: ' || NEW.titulo
    );

    RETURN NEW;

END;
$$;


CREATE TRIGGER trg_registrar_historico_partida
AFTER INSERT ON partidas
FOR EACH ROW
EXECUTE FUNCTION fn_registrar_historico_partida();


CREATE OR REPLACE FUNCTION fn_buscar_jogadores(p_termo TEXT)
RETURNS TABLE (
    id_jogador INT,
    nickname VARCHAR(40),
    email VARCHAR(120)
)
LANGUAGE plpgsql
AS $$
BEGIN

    RETURN QUERY

    SELECT
        j.id_jogador,
        j.nickname,
        j.email

    FROM jogadores j

    WHERE j.nickname ILIKE '%' || p_termo || '%'
       OR j.email ILIKE '%' || p_termo || '%'

    ORDER BY j.nickname;

END;
$$;


CREATE OR REPLACE VIEW vw_painel_principal AS

SELECT
    j.nickname,
    p.titulo AS titulo_partida,
    m.nome AS modalidade,
    p.data_agendamento AS data_partida,
    p.status_partida

FROM partidas p

INNER JOIN jogadores j
    ON j.id_jogador = p.id_jogador

INNER JOIN modalidades m
    ON m.id_modalidade = p.id_modalidade;


CREATE OR REPLACE VIEW vw_cronograma_partidas AS

SELECT
    p.id_partida,
    p.titulo AS titulo_partida,
    p.data_agendamento,
    p.status_partida,

    (p.data_agendamento::DATE - CURRENT_DATE)
        AS dias_restantes,

    j.nickname AS jogador_responsavel,
    m.nome AS modalidade

FROM partidas p

INNER JOIN jogadores j
    ON j.id_jogador = p.id_jogador

INNER JOIN modalidades m
    ON m.id_modalidade = p.id_modalidade

ORDER BY p.data_agendamento ASC;


INSERT INTO jogadores
(nickname, email, senha, status_conta)
VALUES
('D4viFPS', 'davi@email.com', 'senha123', 'ATIVO'),
('TheoPlay', 'theo@email.com', 'theo123', 'ATIVO'),
('PlayerInativo', 'inativo@email.com', 'teste123', 'INATIVO');


INSERT INTO modalidades
(nome, categoria)
VALUES
('Valorant', 'FPS'),
('Fortnite', 'BATTLE ROYALE'),
('League of Legends', 'MOBA');


INSERT INTO partidas
(titulo, id_jogador, id_modalidade, data_agendamento, status_partida)
VALUES
(
    'D4viFPS x TheoPlay - Valorant',
    1,
    1,
    CURRENT_TIMESTAMP + INTERVAL '2 days',
    'AGENDADA'
),
(
    'Campeonato Fortnite - Rodada 1',
    2,
    2,
    CURRENT_TIMESTAMP + INTERVAL '5 days',
    'AGENDADA'
),
(
    'Final League of Legends',
    1,
    3,
    CURRENT_TIMESTAMP + INTERVAL '8 days',
    'AGENDADA'
);


-- CONSULTAR AS TABELAS

SELECT * FROM jogadores;

SELECT * FROM modalidades;

SELECT * FROM partidas;

SELECT * FROM historico_partidas;


--  CONSULTAR AS VIEWS

SELECT * FROM vw_painel_principal;

SELECT *
FROM vw_cronograma_partidas
ORDER BY data_agendamento ASC;


--  TESTAR A FUNCAO DE BUSCA

SELECT * FROM fn_buscar_jogadores('davi');

