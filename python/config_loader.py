import os
import yaml

_CONFIG_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "config.yaml")

_config: dict | None = None


def _load_yaml(path: str) -> dict:
    """读取 YAML 配置文件，文件不存在时返回空字典。"""
    if not os.path.isfile(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def _merge_env(config: dict, prefix: str = "AI_") -> dict:
    """递归注入环境变量：AI_COLLECTOR_SNAPSHOT_DIR → config['collector']['snapshot_dir']"""
    for key, value in os.environ.items():
        if not key.startswith(prefix):
            continue
        parts = key[len(prefix):].lower().split("_")
        target = config
        for part in parts[:-1]:
            if part not in target:
                target[part] = {}
            target = target[part]
        target[parts[-1]] = value
    return config


def load_config(reload: bool = False) -> dict:
    """加载配置（惰性缓存，可通过 reload=True 强制重载）。"""
    global _config
    if _config is not None and not reload:
        return _config
    _config = _merge_env(_load_yaml(_CONFIG_PATH))
    return _config


def get(key: str, default=None):
    """按点号分隔键取值，如 get('ai.timeout', 30)。"""
    config = load_config()
    parts = key.split(".")
    for part in parts:
        if isinstance(config, dict):
            config = config.get(part)
        else:
            return default
        if config is None:
            return default
    return config
