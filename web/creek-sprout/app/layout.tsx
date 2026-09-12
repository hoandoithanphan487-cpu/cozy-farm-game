import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: '溪谷新芽｜正式网页版',
  description:
    '《溪谷新芽》正式网页版：农场生活、溪岸集市、五种作物、制作加工、畜牧猫店与十段主剧情。',
  openGraph: {
    title: '溪谷新芽｜正式网页版',
    description: '打开即进入溪谷农场，继续完整生活与主线故事。',
    type: 'website',
    locale: 'zh_CN',
  },
  twitter: {
    card: 'summary',
    title: '溪谷新芽｜正式网页版',
    description: '原创温馨农场生活游戏正式网页版。',
  },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
