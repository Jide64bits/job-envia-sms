import re
import requests
import psycopg2
from urllib.parse import quote
from utils.utils import registralog
from datetime import date,timedelta
from jinja2 import Template
from datetime import datetime
from google.cloud import storage
from utils.envs import Envs as envs


def conectar_db():
    return psycopg2.connect(
        host=envs.DB_HOST,
        user=envs.DB_USER,
        password=envs.DB_PASSWORD,
        dbname=envs.DB_NAME,
        port=int(envs.DB_PORT),
        options="-c idle_in_transaction_session_timeout=0",
    )



def enviar_whatsapp(telefone, mensagem):
    telefone = re.sub(r'\D', '', telefone)

    if not telefone.startswith('55'):
        telefone = '55' + telefone

    url = f"{envs.EVOLUTION_BASE_URL}/message/sendText/{quote(envs.EVOLUTION_INSTANCE)}"
    headers = {
        "Content-Type": "application/json",
        "apikey": envs.EVOLUTION_API_KEY
    }
    payload = {
        "number": telefone,
        "text": mensagem
    }

    resp = requests.post(url, headers=headers, json=payload)
    if resp.status_code in (200, 201):
        registralog(f"WhatsApp enviado para {telefone}")
    else:
        registralog(f"Erro ao enviar WhatsApp para {telefone}: {resp.text}")


def main():

    conexao = conectar_db() 
    
    cursor = conexao.cursor()

    ## Manda mensagem sobre o agendamento
    query = """select split_part(p.responsible_name, ' ', 1) 
                , split_part(p."name", ' ', 1) 
                , a."date" 
                , a."time"
                , p.phone from appointments a 
                        , patients p 
            where a.user_id = '91f8088b-ddef-4c68-9da2-aa990316511b'
            and p.id = a.patient_id 
            and (a.date::text || ' ' || a.time)::timestamp between now() and now() + interval '2 day' 
                      """
    cursor.execute(query)

    resultados = cursor.fetchall()

    for agendamento in resultados:


        responsavel,paciente,data_agendada,hora_agendada,telefone = agendamento

   #     telefone = '51991960468'

        mensagem = (
            f"Olá, {responsavel}!\n\n"
            f"Lembramos que *{paciente}* tem consulta no dia "
            f"*{data_agendada.strftime('%d/%m')}, às {hora_agendada}hs*.\n\n"
            f"Pode confirmar a presença?\n\n"
            f"Lembramos que *cancelamentos no dia e faltas sem aviso prévio são cobrados normalmente*.\n\n"
            f"Obrigado!"
        )
        enviar_whatsapp(telefone, mensagem)


   ## Manda mensagem sobre o agendamento
    try:
        query2 = """SELECT split_part(p.responsible_name, ' ', 1) AS responsavel
                         , split_part(p.name, ' ', 1) AS paciente
                         , COUNT(*) AS qtd_consultas
                         , STRING_AGG(to_char(s.date, 'DD/MM/YYYY'),', ' ORDER BY s.date) AS datas
                         , SUM(p.consultation_value) AS valor_total
                         , p.phone
                         , to_char(now() - interval '1 day','MM/YYYY')
                    FROM sessions s
                    LEFT JOIN appointments a ON s.appointment_id = a.id
                    INNER JOIN patients p ON p.id = s.patient_id
                    WHERE s.user_id = '91f8088b-ddef-4c68-9da2-aa990316511b'
                      AND s.paid = false
                      and extract(day from current_date) = 1
                    GROUP BY p.responsible_name
                           , p.name
                           , p.phone
                    ORDER BY p.responsible_name,
                        p.name"""
        cursor.execute(query2)

        resultados_pa = cursor.fetchall()

        for paciente in resultados_pa:


            responsavel,nome_paciente,quantidade_consultas,datas,valor_total,telefone,mes_ano_referencia = paciente

      #      telefone = '51991960468'

            mensagem = (
                f"Olá, tudo bem {responsavel}?\n\n"
                f"Segue o resumo dos atendimentos do mês de *{mes_ano_referencia}* do paciente {nome_paciente}:\n\n"
                f"*Sessões:* *{quantidade_consultas}* dias *{datas}*\n"
                f"*Valor:* R$ *{valor_total}*\n\n"
                f"O pagamento deverá ser realizado *até o 5º dia útil do mês*, conforme contrato.\n\n"
                f"*Chave Pix:* 58.020.384/0001-94\n\n"
                f"Após o pagamento, solicitamos o envio do comprovante. Em caso de atraso, poderão ser cobrados juros, conforme previsto em contrato."
            )
            enviar_whatsapp(telefone, mensagem)

           # telefone = '51991960468'
                
    except Exception as e:
        print(f"Erro ao processar dados: {e}")


if __name__ == "__main__":
    main()