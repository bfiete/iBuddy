using Beefy.widgets;
using Beefy.gfx;
using Beefy.theme.dark;
using System;

namespace iBuddy
{
	class ConfigWidget : Widget
	{
		public DarkComboBox mRecordCombo;

		

		public this()
		{
			mRecordCombo = new DarkComboBox();
			AddWidget(mRecordCombo);
			mRecordCombo.mPopulateMenuAction.Add(new (menu) =>
				{
					void AddItem(StringView label)
					{
						var item = menu.AddItem(label);
						item.mOnMenuItemSelected.Add(new (menu) =>
							{
								mRecordCombo.Label = menu.mLabel;
							});
					}

					AddItem("Disabled");
					AddItem("Record");
					AddItem("Compare");
				});
			mRecordCombo.Label = "Disabled";

			ResizeComponents();
		}

		void ResizeComponents()
		{
			mRecordCombo.Resize(8, 30, 200, 20);
		}

		public override void Update()
		{
			base.Update();
			//ResizeComponents();
		}

		public override void Draw(Graphics g)
		{
			base.Draw(g);

			using (g.PushColor(0xFF000020))
				g.FillRect(0, 0, mWidth, mHeight);

			g.SetFont(DarkTheme.sDarkTheme.mSmallFont);
			g.DrawString("Lap Input Recording", mRecordCombo.mX, mRecordCombo.mY - 20);
		}
	}
}
