"""
Middleware de Segurança
======================

Implementações de segurança para a API sem autenticação.
"""

from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
import re
import logging
from typing import Optional
import time

logger = logging.getLogger(__name__)

class SecurityMiddleware:
    """Middleware de segurança para validação e proteção"""
    
    def __init__(self):
        self.blocked_ips = set()
        self.suspicious_requests = {}
        self.max_suspicious_requests = 10
        self.block_duration = 300  # 5 minutos
    
    def validate_input(self, value: str, max_length: int = 100) -> str:
        """Validar e sanitizar input de string"""
        if not value:
            raise HTTPException(status_code=400, detail="Valor não pode ser vazio")
        
        if len(value) > max_length:
            raise HTTPException(status_code=400, detail=f"Valor muito longo (máximo {max_length} caracteres)")
        
        # Remover caracteres perigosos
        dangerous_chars = ['<', '>', '"', "'", '&', ';', '(', ')', '{', '}', '[', ']']
        for char in dangerous_chars:
            if char in value:
                raise HTTPException(status_code=400, detail="Caracteres perigosos detectados")
        
        return value.strip()
    
    def validate_character_name(self, name: str) -> str:
        """Validar nome de personagem"""
        if not name or len(name) < 2 or len(name) > 20:
            raise HTTPException(status_code=400, detail="Nome deve ter entre 2 e 20 caracteres")
        
        # Apenas letras, números e espaços
        if not re.match(r'^[a-zA-Z0-9\s]+$', name):
            raise HTTPException(status_code=400, detail="Nome contém caracteres inválidos")
        
        return name.strip()
    
    def validate_server_name(self, server: str) -> str:
        """Validar nome do servidor"""
        valid_servers = ["taleon", "rubini", "rubinot"]
        if server.lower() not in valid_servers:
            raise HTTPException(status_code=400, detail=f"Servidor inválido. Válidos: {', '.join(valid_servers)}")
        return server.lower()
    
    def validate_world_name(self, world: str) -> str:
        """Validar nome do world"""
        if not world or len(world) < 2 or len(world) > 10:
            raise HTTPException(status_code=400, detail="World deve ter entre 2 e 10 caracteres")
        
        # Apenas letras e números
        if not re.match(r'^[a-zA-Z0-9]+$', world):
            raise HTTPException(status_code=400, detail="World contém caracteres inválidos")
        
        return world.lower()
    
    def detect_suspicious_activity(self, request: Request) -> bool:
        """Detectar atividade suspeita"""
        client_ip = request.client.host
        
        # Verificar se IP está bloqueado
        if client_ip in self.blocked_ips:
            return True
        
        # Verificar User-Agent suspeito
        user_agent = request.headers.get("user-agent", "")
        suspicious_ua_patterns = [
            "bot", "crawler", "spider", "scraper", "curl", "wget", 
            "python", "java", "perl", "ruby", "php"
        ]
        
        if any(pattern in user_agent.lower() for pattern in suspicious_ua_patterns):
            self._increment_suspicious_requests(client_ip)
            return True
        
        # Verificar requests muito frequentes
        current_time = time.time()
        if client_ip in self.suspicious_requests:
            requests = self.suspicious_requests[client_ip]
            # Limpar requests antigos (mais de 1 minuto)
            requests = [req_time for req_time in requests if current_time - req_time < 60]
            
            if len(requests) > 100:  # Mais de 100 requests por minuto
                self._block_ip(client_ip)
                return True
            
            requests.append(current_time)
            self.suspicious_requests[client_ip] = requests
        else:
            self.suspicious_requests[client_ip] = [current_time]
        
        return False
    
    def _increment_suspicious_requests(self, client_ip: str):
        """Incrementar contador de requests suspeitos"""
        if client_ip not in self.suspicious_requests:
            self.suspicious_requests[client_ip] = []
        
        self.suspicious_requests[client_ip].append(time.time())
        
        if len(self.suspicious_requests[client_ip]) >= self.max_suspicious_requests:
            self._block_ip(client_ip)
    
    def _block_ip(self, client_ip: str):
        """Bloquear IP temporariamente"""
        self.blocked_ips.add(client_ip)
        logger.warning(f"IP {client_ip} bloqueado por atividade suspeita")
        
        # Remover bloqueio após o tempo definido
        def unblock_ip():
            time.sleep(self.block_duration)
            if client_ip in self.blocked_ips:
                self.blocked_ips.remove(client_ip)
                logger.info(f"IP {client_ip} desbloqueado")
        
        import threading
        threading.Thread(target=unblock_ip, daemon=True).start()
    
    def validate_query_params(self, request: Request) -> dict:
        """Validar parâmetros de query"""
        params = {}
        
        for key, value in request.query_params.items():
            if key in ['skip', 'limit', 'days']:
                try:
                    params[key] = int(value)
                    if params[key] < 0:
                        raise HTTPException(status_code=400, detail=f"{key} deve ser positivo")
                except ValueError:
                    raise HTTPException(status_code=400, detail=f"{key} deve ser um número")
            else:
                params[key] = self.validate_input(value)
        
        return params

# Instância global do middleware
security_middleware = SecurityMiddleware() 