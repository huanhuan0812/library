import os
import shutil
import hashlib
import argparse
from pathlib import Path

class FolderSyncTool:
    def __init__(self, source_dir, target_dir, dry_run=False, verbose=False):
        self.source_dir = Path(source_dir).resolve()
        self.target_dir = Path(target_dir).resolve()
        self.dry_run = dry_run
        self.verbose = verbose
        
        # 确保源目录存在
        if not self.source_dir.exists():
            raise ValueError(f"源目录不存在: {self.source_dir}")
        
        # 如果目标目录不存在，则创建
        if not self.target_dir.exists():
            if not self.dry_run:
                self.target_dir.mkdir(parents=True, exist_ok=True)
            if self.verbose:
                print(f"创建目标目录: {self.target_dir}")
    
    def calculate_file_hash(self, file_path):
        """计算文件的MD5哈希值"""
        hash_md5 = hashlib.md5()
        try:
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except IOError:
            return None
    
    def sync_folders(self):
        """同步两个文件夹"""
        # 获取源目录和目标目录中的所有文件（相对路径）
        source_files = {}
        for root, _, files in os.walk(self.source_dir):
            for file in files:
                rel_path = Path(root).relative_to(self.source_dir)
                source_files[rel_path / file] = Path(root) / file
        
        target_files = {}
        for root, _, files in os.walk(self.target_dir):
            for file in files:
                rel_path = Path(root).relative_to(self.target_dir)
                target_files[rel_path / file] = Path(root) / file
        
        # 找出需要删除的文件（在目标目录但不在源目录）
        files_to_delete = set(target_files.keys()) - set(source_files.keys())
        
        # 找出需要更新或添加的文件
        files_to_update = []
        for rel_path in set(source_files.keys()):
            source_file = source_files[rel_path]
            target_file = self.target_dir / rel_path
            
            # 如果目标文件不存在，需要添加
            if rel_path not in target_files:
                files_to_update.append((source_file, target_file))
                continue
            
            # 如果目标文件存在，比较哈希值
            source_hash = self.calculate_file_hash(source_file)
            target_hash = self.calculate_file_hash(target_files[rel_path])
            
            # 如果哈希值不同，需要更新
            if source_hash != target_hash:
                files_to_update.append((source_file, target_file))
        
        # 执行删除操作
        for rel_path in files_to_delete:
            target_file = self.target_dir / rel_path
            if self.verbose:
                print(f"删除: {target_file}")
            
            if not self.dry_run:
                try:
                    os.remove(target_file)
                    # 如果父目录为空，也删除
                    parent_dir = target_file.parent
                    if parent_dir != self.target_dir and not any(parent_dir.iterdir()):
                        os.rmdir(parent_dir)
                except OSError as e:
                    print(f"删除文件失败 {target_file}: {e}")
        
        # 执行更新/添加操作
        for source_file, target_file in files_to_update:
            if self.verbose:
                if target_file.exists():
                    print(f"更新: {target_file}")
                else:
                    print(f"添加: {target_file}")
            
            if not self.dry_run:
                # 确保目标目录存在
                target_file.parent.mkdir(parents=True, exist_ok=True)
                
                try:
                    shutil.copy2(source_file, target_file)
                except IOError as e:
                    print(f"复制文件失败 {source_file} -> {target_file}: {e}")
        
        # 输出统计信息
        print(f"同步完成:")
        print(f"  删除文件: {len(files_to_delete)}")
        print(f"  更新/添加文件: {len(files_to_update)}")
        print(f"  总文件数: {len(source_files)}")

def main():
    parser = argparse.ArgumentParser(description="同步两个文件夹的内容")
    parser.add_argument("source_dir", help="源目录路径")
    parser.add_argument("target_dir", help="目标目录路径")
    parser.add_argument("--dry-run", action="store_true", 
                       help="模拟运行，不实际执行任何操作")
    parser.add_argument("--verbose", action="store_true", 
                       help="显示详细操作信息")
    
    args = parser.parse_args()
    
    try:
        sync_tool = FolderSyncTool(
            args.source_dir, 
            args.target_dir, 
            args.dry_run, 
            args.verbose
        )
        sync_tool.sync_folders()
    except ValueError as e:
        print(f"错误: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
