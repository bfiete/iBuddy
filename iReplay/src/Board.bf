using Beefy.widgets;
using Beefy.gfx;
using System;
using Beefy.events;

namespace iReplay
{
	class Board : Widget
	{
		public Image mImage ~ delete _;

		public override void Draw(Graphics g)
		{
			using (g.PushColor(0xFF000020))
				g.FillRect(0, 0, mWidth, mHeight);

			g.SetFont(gApp.mMedFont);
			int sec = gApp.mCurDataTick / 1000;
			g.DrawString(scope $"Tick: {sec / 60}:{sec % 60:00} Speed: {gApp.mSpeed:0.0}", 8, 8);

			if (!gApp.mImageData.IsEmpty)
			{
				DeleteAndNullify!(mImage);
				mImage = Image.LoadFromFile(scope $"@{(int)(void*)gApp.mImageData.Ptr:X}:{gApp.mImageData.Count}.jpg");

				gApp.mImageData.Clear();
			}

			if (mImage != null)
			{
				float scaleX = (mWidth - 16) / mImage.mWidth;
				float scaleY = (mHeight - 40) / mImage.mHeight;
				float scale = Math.Min(scaleX, scaleY);

				using (g.PushTranslate(8, 32))
					using (g.PushScale(scale, scale))
						g.Draw(mImage, 0, 0);
			}
		}

		public override void KeyChar(char32 c)
		{
			base.KeyChar(c);

			switch (c)
			{
			case '+',
				 '=':
				gApp.mSpeed *= 1.5f;
			case '-':
				gApp.mSpeed /= 1.5f;
			case '0':
				gApp.mSpeed = 1;
			case '1':
				gApp.mDataTick += 5000.0;
			case '2':
				gApp.mDataTick += 15000.0;
			case '3':
				gApp.mDataTick += 60000.0;
			case 'p':
				gApp.mSpeed = 0;
			}
		}

		public override void KeyDown(KeyCode keyCode, bool isRepeat)
		{
			base.KeyDown(keyCode, isRepeat);

			switch (keyCode)
			{
			case .Left:
				gApp.mDataTick = Math.Max(gApp.mDataTick - 5000, 0);
				gApp.ResyncToHistory();
			case .Right:
				gApp.mDataTick += 5000;
			default:
			}
		}

		public override void Update()
		{
			base.Update();
			SetFocus();
		}
	}
}
