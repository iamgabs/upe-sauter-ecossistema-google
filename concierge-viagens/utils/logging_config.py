import logging
import sys

_COLORS = {
    logging.DEBUG: "\033[36m",     # ciano
    logging.INFO: "\033[32m",      # verde
    logging.WARNING: "\033[33m",   # amarelo
    logging.ERROR: "\033[31m",     # vermelho
    logging.CRITICAL: "\033[35m",  # magenta
}
_RESET = "\033[0m"


class _Formatter(logging.Formatter):
    def __init__(self, use_color: bool):
        super().__init__("%(asctime)s %(levelname)-7s %(name)s: %(message)s", "%H:%M:%S")
        self.use_color = use_color

    def format(self, record: logging.LogRecord) -> str:
        text = super().format(record)
        return f"{_COLORS.get(record.levelno, '')}{text}{_RESET}" if self.use_color else text


def setup_logging(level: int = logging.INFO) -> None:
    """Configura o logger da aplicação (cores só quando a saída é um terminal)."""
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(_Formatter(use_color=sys.stderr.isatty()))
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level)
